/*
 * BUT - The information manager from hell
 *
 * Copyright (C) Eric Biederman, 2005
 */
#include "builtin.h"
#include "config.h"
#include "refs.h"

static const char var_usage[] = "but var (-l | <variable>)";

static const char *editor(int flag)
{
	const char *pgm = but_editor();

	if (!pgm && flag & IDENT_STRICT)
		die("Terminal is dumb, but EDITOR unset");

	return pgm;
}

static const char *pager(int flag)
{
	const char *pgm = but_pager(1);

	if (!pgm)
		pgm = "cat";
	return pgm;
}

static const char *default_branch(int flag)
{
	return but_default_branch_name(1);
}

struct but_var {
	const char *name;
	const char *(*read)(int);
};
static struct but_var but_vars[] = {
	{ "BUT_CUMMITTER_IDENT", but_cummitter_info },
	{ "BUT_AUTHOR_IDENT",   but_author_info },
	{ "BUT_EDITOR", editor },
	{ "BUT_PAGER", pager },
	{ "BUT_DEFAULT_BRANCH", default_branch },
	{ "", NULL },
};

static void list_vars(void)
{
	struct but_var *ptr;
	const char *val;

	for (ptr = but_vars; ptr->read; ptr++)
		if ((val = ptr->read(0)))
			printf("%s=%s\n", ptr->name, val);
}

static const char *read_var(const char *var)
{
	struct but_var *ptr;
	const char *val;
	val = NULL;
	for (ptr = but_vars; ptr->read; ptr++) {
		if (strcmp(var, ptr->name) == 0) {
			val = ptr->read(IDENT_STRICT);
			break;
		}
	}
	return val;
}

static int show_config(const char *var, const char *value, void *cb)
{
	if (value)
		printf("%s=%s\n", var, value);
	else
		printf("%s\n", var);
	return but_default_config(var, value, cb);
}

int cmd_var(int argc, const char **argv, const char *prefix)
{
	const char *val = NULL;
	if (argc != 2)
		usage(var_usage);

	if (strcmp(argv[1], "-l") == 0) {
		but_config(show_config, NULL);
		list_vars();
		return 0;
	}
	but_config(but_default_config, NULL);
	val = read_var(argv[1]);
	if (!val)
		usage(var_usage);

	printf("%s\n", val);

	return 0;
}
