/*
 * Support for UTIO FMC card components
 */

#ifndef UTIO_H
#define UTIO_H

#include <stdint.h>

void utioInit(void);
void utioCrank(void);
uint32_t *utioFetchSysmon(uint32_t *ap);

#endif /* UTIO_H */

