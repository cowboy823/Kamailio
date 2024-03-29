/*
 * MIT License
 *
 * Portions created by ONEm Communications Ltd. are Copyright (c) 2016
 * ONEm Communications Ltd. All Rights Reserved.
 *
 * Portions created by ng-voice are Copyright (c) 2016
 * ng-voice. All Rights Reserved.
 *
 * Portions created by Alan Antonuk are Copyright (c) 2012-2013
 * Alan Antonuk. All Rights Reserved.
 *
 * Portions created by VMware are Copyright (c) 2007-2012 VMware, Inc.
 * All Rights Reserved.
 *
 * Portions created by Tony Garnock-Jones are Copyright (c) 2009-2010
 * VMware, Inc. and Tony Garnock-Jones. All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>

#include <stdint.h>

#if RABBITMQ_DEPRECATION
#include <rabbitmq-c/amqp.h>
#include <rabbitmq-c/framing.h>
#else
#include <amqp.h>
#include <amqp_framing.h>
#endif

#include "utils.h"

int log_on_error(int x, char const *context)
{
	if(x < 0) {
		LM_ERR("%s: %s\n", context, amqp_error_string2(x));
		return x;
	}

	return AMQP_RESPONSE_NORMAL;
}

int log_on_amqp_error(amqp_rpc_reply_t x, char const *context)
{
	switch(x.reply_type) {
		case AMQP_RESPONSE_NONE:
			LM_NOTICE("%s: AMQP_RESPONSE_NONE\n", context);
			return AMQP_RESPONSE_NONE;

		case AMQP_RESPONSE_NORMAL:
			LM_DBG("%s: AMQP_RESPONSE_NORMAL\n", context);
			return AMQP_RESPONSE_NORMAL;

		case AMQP_RESPONSE_LIBRARY_EXCEPTION:
			LM_ERR("%s: AMQP_RESPONSE_LIBRARY_EXCEPTION: %s\n", context,
					amqp_error_string2(x.library_error));
			return AMQP_RESPONSE_LIBRARY_EXCEPTION;

		case AMQP_RESPONSE_SERVER_EXCEPTION:
			switch(x.reply.id) {
				case AMQP_CONNECTION_CLOSE_METHOD: {
					amqp_connection_close_t *m =
							(amqp_connection_close_t *)x.reply.decoded;
					LM_ERR("%s: AMQP_CONNECTION_CLOSE_METHOD: server "
						   "connection error %uh, message: %.*s\n",
							context, m->reply_code, (int)m->reply_text.len,
							(char *)m->reply_text.bytes);
					break;
				}

				case AMQP_CHANNEL_CLOSE_METHOD: {
					amqp_channel_close_t *m =
							(amqp_channel_close_t *)x.reply.decoded;
					LM_ERR("%s: AMQP_CHANNEL_CLOSE_METHOD: server channel "
						   "error %uh, message: %.*s\n",
							context, m->reply_code, (int)m->reply_text.len,
							(char *)m->reply_text.bytes);
					break;
				}

				default:
					LM_ERR("%s: unknown server error, method id 0x%08X\n",
							context, x.reply.id);
					break;
			}

			LM_ERR("%s: AMQP_RESPONSE_SERVER_EXCEPTION: %s\n", context,
					amqp_error_string2(x.library_error));
			return AMQP_RESPONSE_SERVER_EXCEPTION;

		default:
			LM_ERR("%s: unknown reply type 0x%08X\n", context, x.reply_type);
			return x.reply_type;
	}
}

static void dump_row(long count, int numinrow, int *chs)
{
	int i;

	printf("%08lX:", count - numinrow);

	if(numinrow > 0) {
		for(i = 0; i < numinrow; i++) {
			if(i == 8) {
				printf(" :");
			}
			printf(" %02X", chs[i]);
		}
		for(i = numinrow; i < 16; i++) {
			if(i == 8) {
				printf(" :");
			}
			printf("	 ");
		}
		printf("	");
		for(i = 0; i < numinrow; i++) {
			if(isprint(chs[i])) {
				printf("%c", chs[i]);
			} else {
				printf(".");
			}
		}
	}
	printf("\n");
}

static int rows_eq(int *a, int *b)
{
	int i;

	for(i = 0; i < 16; i++)
		if(a[i] != b[i]) {
			return 0;
		}

	return 1;
}

void amqp_dump(void const *buffer, size_t len)
{
	unsigned char *buf = (unsigned char *)buffer;
	long count = 0;
	int numinrow = 0;
	int chs[16];
	int oldchs[16] = {0};
	int showed_dots = 0;
	size_t i;

	for(i = 0; i < len; i++) {
		int ch = buf[i];

		if(numinrow == 16) {
			int j;

			if(rows_eq(oldchs, chs)) {
				if(!showed_dots) {
					showed_dots = 1;
					printf("					.. .. .. .. .. .. .. .. : .. "
						   ".. "
						   ".. .. .. .. .. ..\n");
				}
			} else {
				showed_dots = 0;
				dump_row(count, numinrow, chs);
			}

			for(j = 0; j < 16; j++) {
				oldchs[j] = chs[j];
			}

			numinrow = 0;
		}

		count++;
		chs[numinrow++] = ch;
	}

	dump_row(count, numinrow, chs);

	if(numinrow != 0) {
		printf("%08lX:\n", count);
	}
}
