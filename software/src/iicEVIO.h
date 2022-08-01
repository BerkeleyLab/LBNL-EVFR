/*
 * Xilinx AXI IIC to FMC slot 1 components (EVIO)
 */
#ifndef _IIC_EVIO_H_
#define _IIC_EVIO_H_

void iicEVIOinit(void);
int iicEVIOsend(int address7, int subaddress, const unsigned char *buf,int len);
int iicEVIOrecv(int address7, int subaddress, unsigned char *buf, int len);
int iicEVIOgetGPO(void);
void iicEVIOsetGPO(int gpo);

#endif /* _IIC_EVIO_H_ */
