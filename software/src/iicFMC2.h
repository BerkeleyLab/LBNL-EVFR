/*
 * Xilinx AXI IIC to FMC slot 2 components (UTIO for now, EVRIO someday)
 */
#ifndef _IIC_FMC2_H_
#define _IIC_FMC2_H_

void iicFMC2init(void);
int iicFMC2send(int address7, int subaddress, const unsigned char *buf,int len);
int iicFMC2recv(int address7, int subaddress, unsigned char *buf, int len);

#endif /* _IIC_FMC2_H_ */
