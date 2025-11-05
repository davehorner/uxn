/*
 * Windows implementation of file operations for UXN
 * This provides Windows-compatible file I/O using Win32 APIs
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <io.h>
#include <direct.h>
#include <sys/stat.h>
#include <windows.h>
#include "../uxn.h"
#include "file.h"

#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

#define DIR_SEP_CHAR '\\'
#define DIR_SEP_STR "\\"

/* Safe POKE2 wrapper to avoid type conversion warnings */
#define POKE2_SAFE(d, v) do { \
	Uint16 val = (Uint16)(v); \
	*(d) = (Uint8)(val >> 8); \
	(d)[1] = (Uint8)(val); \
} while(0)

typedef struct {
	FILE *f;
	HANDLE hFind;
	WIN32_FIND_DATAA findData;
	char current_filename[PATH_MAX];
	char search_pattern[PATH_MAX];
	int first_find;
	enum { IDLE,
		FILE_READ,
		FILE_WRITE,
		DIR_READ,
		DIR_WRITE
	} state;
	int outside_sandbox;
} UxnFile;

static UxnFile uxn_file[POLYFILEY];

static void
reset(UxnFile *c)
{
	if(c->f != NULL) {
		fclose(c->f);
		c->f = NULL;
	}
	if(c->hFind != INVALID_HANDLE_VALUE) {
		FindClose(c->hFind);
		c->hFind = INVALID_HANDLE_VALUE;
	}
	c->state = IDLE;
	c->outside_sandbox = 0;
	c->first_find = 1;
}

static Uint16
get_entry(char *p, UxnFile *c)
{
	struct _stat st;
	if(c->hFind == INVALID_HANDLE_VALUE) return 0;
	
	if(c->first_find) {
		c->first_find = 0;
	} else {
		if(!FindNextFileA(c->hFind, &c->findData)) {
			FindClose(c->hFind);
			c->hFind = INVALID_HANDLE_VALUE;
			return 0;
		}
	}
	
	/* Build full path for stat */
	char full_path[PATH_MAX];
	char *dir_part = c->search_pattern;
	char *last_slash = strrchr(dir_part, '\\');
	if(last_slash) {
		size_t dir_len = (size_t)(last_slash - dir_part + 1);
		if(dir_len < PATH_MAX) {
			memcpy_s(full_path, PATH_MAX, dir_part, dir_len);
			full_path[dir_len] = '\0';
			if(strlen(full_path) + strlen(c->findData.cFileName) < PATH_MAX - 1) {
				strcat_s(full_path, PATH_MAX, c->findData.cFileName);
			}
		}
	} else {
		if(strlen(c->findData.cFileName) < PATH_MAX - 1) {
			strcpy_s(full_path, PATH_MAX, c->findData.cFileName);
		}
	}
	
	if(_stat(full_path, &st))
		st.st_size = 0;
	
	int result = _snprintf_s(p, PATH_MAX, _TRUNCATE, "%s\n%c%08x\n", 
		c->findData.cFileName,
		(c->findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ? 'd' : 'f',
		(unsigned int)st.st_size);
	return (result > 0) ? (Uint16)result : 0;
}

static Uint16
file_init(UxnFile *c, char *filename, size_t max_len, int override_sandbox)
{
	reset(c);
	
	if(max_len > PATH_MAX)
		max_len = PATH_MAX;
	
	/* Copy and null-terminate the filename */
	size_t len = 0;
	while(len < max_len - 1 && filename[len] != '\0')
		len++;
	
	if(len > 0) {
		strncpy_s(c->current_filename, PATH_MAX, filename, len);
		c->current_filename[len] = '\0';
	} else {
		c->current_filename[0] = '\0';
	}
	
	/* Basic sandbox check - prevent access to parent directories */
	if(!override_sandbox && strstr(c->current_filename, "..")) {
		c->outside_sandbox = 1;
		return 0;
	}
	
	return 1;
}

static Uint16 
file_read(UxnFile *c, void *dest, Uint16 len)
{
	if(c->state != FILE_READ) {
		reset(c);
		if(c->outside_sandbox) return 0;
		errno_t err = fopen_s(&c->f, c->current_filename, "rb");
		if(err != 0 || c->f == NULL) return 0;
		c->state = FILE_READ;
	}
	if(c->f == NULL) return 0;
	return (Uint16)fread(dest, 1, len, c->f);
}

static Uint16
file_write(UxnFile *c, void *src, Uint16 len, Uint8 flags)
{
	if(c->state != FILE_WRITE) {
		reset(c);
		if(c->outside_sandbox) return 0;
		errno_t err = fopen_s(&c->f, c->current_filename, (flags & 0x01) ? "ab" : "wb");
		if(err != 0 || c->f == NULL) return 0;
		c->state = FILE_WRITE;
	}
	if(c->f == NULL) return 0;
	return (Uint16)fwrite(src, 1, len, c->f);
}

static Uint16
file_stat(UxnFile *c, void *dest, Uint16 len)
{
	struct _stat st;
	reset(c);
	if(c->outside_sandbox) return 0;
	
	if(_stat(c->current_filename, &st)) 
		return 0;
	
	int result = _snprintf_s((char *)dest, len, _TRUNCATE, "%s\n%c%08x\n", 
		c->current_filename,
		(st.st_mode & _S_IFDIR) ? 'd' : 'f',
		(unsigned int)st.st_size);
	return (result > 0) ? (Uint16)result : 0;
}

static Uint16
file_delete(UxnFile *c)
{
	reset(c);
	if(c->outside_sandbox) return 0;
	
	struct _stat st;
	if(_stat(c->current_filename, &st))
		return 0;
		
	if(st.st_mode & _S_IFDIR) {
		return _rmdir(c->current_filename) == 0 ? 1 : 0;
	} else {
		return _unlink(c->current_filename) == 0 ? 1 : 0;
	}
}

static Uint16
dir_read(UxnFile *c, void *dest, Uint16 len)
{
	if(c->state != DIR_READ) {
		reset(c);
		if(c->outside_sandbox) return 0;
		
		/* Prepare search pattern */
		_snprintf_s(c->search_pattern, sizeof(c->search_pattern), _TRUNCATE, "%s\\*", c->current_filename);
		c->hFind = FindFirstFileA(c->search_pattern, &c->findData);
		
		if(c->hFind == INVALID_HANDLE_VALUE) return 0;
		c->state = DIR_READ;
		c->first_find = 1;
	}
	
	return get_entry((char *)dest, c);
}

static Uint16
dir_write(UxnFile *c)
{
	reset(c);
	if(c->outside_sandbox) return 0;
	return _mkdir(c->current_filename) == 0 ? 1 : 0;
}

void
file_deo(Uint8 port)
{
	Uint16 addr, len, res;
	switch(port) {
	case 0xa5:
		addr = PEEK2(&uxn.dev[0xa4]);
		len = PEEK2(&uxn.dev[0xaa]);
		if(len > 0x10000 - addr)
			len = 0x10000 - addr;
		res = file_stat(&uxn_file[0], &uxn.ram[addr], len);
		POKE2_SAFE(&uxn.dev[0xa2], res);
		break;
	case 0xa6:
		res = file_delete(&uxn_file[0]);
		POKE2_SAFE(&uxn.dev[0xa2], res);
		break;
	case 0xa9:
		addr = PEEK2(&uxn.dev[0xa8]);
		res = file_init(&uxn_file[0], (char *)&uxn.ram[addr], (size_t)(0x10000 - addr), 0);
		POKE2_SAFE(&uxn.dev[0xa2], res);
		break;
	case 0xad:
		addr = PEEK2(&uxn.dev[0xac]);
		len = PEEK2(&uxn.dev[0xaa]);
		if(len > 0x10000 - addr)
			len = 0x10000 - addr;
		res = file_read(&uxn_file[0], &uxn.ram[addr], len);
		POKE2_SAFE(&uxn.dev[0xa2], res);
		break;
	case 0xaf:
		addr = PEEK2(&uxn.dev[0xae]);
		len = PEEK2(&uxn.dev[0xaa]);
		if(len > 0x10000 - addr)
			len = 0x10000 - addr;
		res = file_write(&uxn_file[0], &uxn.ram[addr], len, uxn.dev[0xa7]);
		POKE2_SAFE(&uxn.dev[0xa2], res);
		break;
	case 0xb5:
		addr = PEEK2(&uxn.dev[0xb4]);
		len = PEEK2(&uxn.dev[0xba]);
		if(len > 0x10000 - addr)
			len = 0x10000 - addr;
		res = file_stat(&uxn_file[1], &uxn.ram[addr], len);
		POKE2_SAFE(&uxn.dev[0xb2], res);
		break;
	case 0xb6:
		res = file_delete(&uxn_file[1]);
		POKE2_SAFE(&uxn.dev[0xb2], res);
		break;
	case 0xb9:
		addr = PEEK2(&uxn.dev[0xb8]);
		res = file_init(&uxn_file[1], (char *)&uxn.ram[addr], (size_t)(0x10000 - addr), 0);
		POKE2_SAFE(&uxn.dev[0xb2], res);
		break;
	case 0xbc:
		addr = PEEK2(&uxn.dev[0xbb]);
		len = PEEK2(&uxn.dev[0xba]);
		if(len > 0x10000 - addr)
			len = 0x10000 - addr;
		res = dir_read(&uxn_file[1], &uxn.ram[addr], len);
		POKE2_SAFE(&uxn.dev[0xb2], res);
		break;
	case 0xbd:
		addr = PEEK2(&uxn.dev[0xbc]);
		len = PEEK2(&uxn.dev[0xba]);
		if(len > 0x10000 - addr)
			len = 0x10000 - addr;
		res = file_read(&uxn_file[1], &uxn.ram[addr], len);
		POKE2_SAFE(&uxn.dev[0xb2], res);
		break;
	case 0xbe:
		res = dir_write(&uxn_file[1]);
		POKE2_SAFE(&uxn.dev[0xb2], res);
		break;
	case 0xbf:
		addr = PEEK2(&uxn.dev[0xbe]);
		len = PEEK2(&uxn.dev[0xba]);
		if(len > 0x10000 - addr)
			len = 0x10000 - addr;
		res = file_write(&uxn_file[1], &uxn.ram[addr], len, uxn.dev[0xb7]);
		POKE2_SAFE(&uxn.dev[0xb2], res);
		break;
	}
}