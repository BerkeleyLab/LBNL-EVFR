/*
 * Support for EVIO FMC card components:
 *  ADN4605 40x40 crosspoint switch
 *  Firefly modules
 */

#ifndef EVIO_H
#define EVIO_H

#include <stdint.h>

void evioInit(void);
void evioCrank(void);
void evioSetLoopback(int loopbackChannel);
void evioShowCrosspointRegisters(void);
uint32_t *evioFetchSysmon(uint32_t *ap);

#endif /* EVIO_H */

