/**@file      unit.h
 * @brief     A very minimal unit test framework header only library
 * @copyright Richard James Howe (2018)
 * @license   MIT */

#ifndef UNIT_TEST_H
#define UNIT_TEST_H

#include <stdio.h>
#include <stdlib.h>

#define UNIT_TEST_OUTPUT (stdout)
static unsigned unit_tests_run, unit_tests_passed;

static inline void _unit_test_start(const char *file, const char *func, unsigned line)
{
	unit_tests_run    = 0;
	unit_tests_passed = 0;
	fprintf(UNIT_TEST_OUTPUT, "Start tests: %s in %s:%d\n\n", func, file, line);
}

static inline void _unit_test(int failed, const char *expr_str, const char *file, const char *func, unsigned line, int die) {
	if(failed) {
		fprintf(UNIT_TEST_OUTPUT, "  FAILED: %s (%s:%s:%d)\n", expr_str, file, func, line);
		if(die) {
			fprintf(UNIT_TEST_OUTPUT, "VERIFY FAILED - EXITING\n");
			exit(EXIT_FAILURE);
		}
	} else {
		fprintf(UNIT_TEST_OUTPUT, "      OK: %s\n", expr_str);
		unit_tests_passed++;
	}
	unit_tests_run++;
}

static inline void unit_test_finish(void) {
	fprintf(UNIT_TEST_OUTPUT, "Tests passed/total: %u/%u\n", unit_tests_passed, unit_tests_run);
	if(unit_tests_run != unit_tests_passed) {
		fprintf(UNIT_TEST_OUTPUT, "[FAILED]\n");
		exit(EXIT_FAILURE);
	}
	fprintf(UNIT_TEST_OUTPUT, "[SUCCESS]\n");
}

#define unit_test_start()      _unit_test_start(__FILE__, __func__, __LINE__)
#define unit_test(EXPR)        _unit_test(0 == (EXPR), (# EXPR), __FILE__, __func__, __LINE__, 0)
#define unit_test_verify(EXPR) _unit_test(0 == (EXPR), (# EXPR), __FILE__, __func__, __LINE__, 1)

#undef UNIT_TEST_OUTPUT

#endif /* UNIT_TEST_H */

