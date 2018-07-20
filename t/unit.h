/**@file      unit.h
 * @brief     A very minimal unit test framework header only library
 * @copyright Richard James Howe (2018)
 * @license   MIT */

#ifndef UNIT_TEST_H
#define UNIT_TEST_H

#include <stdio.h>
#include <stdlib.h>

#define UNIT_TEST_OUTPUT (stdout)

#define CSI     "\x1b["
#define CSIm    "m"
#define BRIGHT  "1;"
#define RED     (CSI BRIGHT "31" CSIm)
#define GREEN   (CSI BRIGHT "32" CSIm)
#define YELLOW  (CSI BRIGHT "33" CSIm)
#define BLUE    (CSI BRIGHT "34" CSIm)
#define MAGENTA (CSI BRIGHT "35" CSIm)
#define CYAN    (CSI BRIGHT "36" CSIm)
#define RESET   (CSI "0" CSIm)

static unsigned unit_tests_run, unit_tests_passed, unit_color_on;

static inline const char *_unit_ansi_reset(void) { return unit_color_on ? RESET : ""; }
static inline const char *_unit_red(void)    { return unit_color_on ? RED    : ""; }
static inline const char *_unit_blue(void)   { return unit_color_on ? BLUE   : ""; }
static inline const char *_unit_green(void)  { return unit_color_on ? GREEN  : ""; }
static inline const char *_unit_yellow(void) { return unit_color_on ? YELLOW : ""; }

static inline void _unit_test_start(const char *file, const char *func, unsigned line)
{
	unit_tests_run    = 0;
	unit_tests_passed = 0;
	fprintf(UNIT_TEST_OUTPUT, "Start tests: %s in %s:%d\n\n", func, file, line);
}

static inline void _unit_test_statement(const char *expr_str)
{
	fprintf(UNIT_TEST_OUTPUT, "   %sSTATE%s: %s\n", _unit_blue(), _unit_ansi_reset(), expr_str);
}

static inline void _unit_test(int failed, const char *expr_str, const char *file, const char *func, unsigned line, int die) {
	if(failed) {
		fprintf(UNIT_TEST_OUTPUT, "  %sFAILED%s: %s (%s:%s:%d)\n", _unit_red(), _unit_ansi_reset(), expr_str, file, func, line);
		if(die) {
			fprintf(UNIT_TEST_OUTPUT, "VERIFY FAILED - EXITING\n");
			exit(EXIT_FAILURE);
		}
	} else {
		fprintf(UNIT_TEST_OUTPUT, "      %sOK%s: %s\n", _unit_green(), _unit_ansi_reset(), expr_str);
		unit_tests_passed++;
	}
	unit_tests_run++;
}

static inline void unit_test_finish(void) {
	fprintf(UNIT_TEST_OUTPUT, "Tests passed/total: %u/%u\n", unit_tests_passed, unit_tests_run);
	if(unit_tests_run != unit_tests_passed) {
		fprintf(UNIT_TEST_OUTPUT, "[%sFAILED%s]\n", _unit_red(), _unit_ansi_reset());
		exit(EXIT_FAILURE);
	}
	fprintf(UNIT_TEST_OUTPUT, "[%sSUCCESS%s]\n", _unit_green(), _unit_ansi_reset());
}

#define unit_test_statement(EXPR) do { EXPR; _unit_test_statement( ( # EXPR ) ); } while(0)
#define unit_test_start()         _unit_test_start(__FILE__, __func__, __LINE__)
#define unit_test(EXPR)           _unit_test(0 == (EXPR), (# EXPR), __FILE__, __func__, __LINE__, 0)
#define unit_test_verify(EXPR)    _unit_test(0 == (EXPR), (# EXPR), __FILE__, __func__, __LINE__, 1)

#undef UNIT_TEST_OUTPUT

#undef CSI     
#undef CSIm   
#undef BRIGHT
#undef RED   
#undef GREEN   
#undef YELLOW 
#undef BLUE    
#undef MAGENTA
#undef CYAN  
#undef RESET

#endif /* UNIT_TEST_H */

