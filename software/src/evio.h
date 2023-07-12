/*
 * Support for EVIO FMC card components:
 *  ADN4605 40x40 crosspoint switch
 *  Firefly modules
 */

#ifndef EVIO_H
#define EVIO_H

#include <stdint.h>

#define EVIO_XCVR_COUNT         3
#define CHANNELS_PER_FIREFLY    12

void evioInit(void);
void evioCrank(void);
void evioSetLoopback(int loopbackChannel);
void evioShowCrosspointRegisters(void);
uint32_t *evioFetchSysmon(uint32_t *ap);
uint16_t getFireflyPresence(void);
uint16_t getFireflyRxLowPower(uint8_t index);
int getFireflyTX0temperature(void);
int getFireflyRX0temperature(void);
int getFireflyTX1temperature(void);
int getFireflyRX1temperature(void);
int getFireflyTX2temperature(void);
int getFireflyRX2temperature(void);
#endif /* EVIO_H */

