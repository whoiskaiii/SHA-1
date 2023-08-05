//.cc文件是Linux/Unix下为C++源文件的默认扩展名。

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <conio.h>
//conio.h，不是C标准库中的头文件，在C standard library，ISO C 和POSIX标准中均没有定义。
//conio是Console Input/Output（控制台输入输出）的简写，其中定义了通过控制台进行数据输入
//和数据输出的函数，主要是一些用户通过按键盘产生的对应操作，比如getch()函数等等。

FILE *w_log, *h_log; //w_log和h_log为FILE *型指针变量。

//生成W(t)，t为计算的轮次。
//unsigned char型数组input为预处理后的message block，大小为64，char的长度为1个byte。
//unsigned int数组w为生成的W(t)，大小为80，int的长度为4个byte。
void creat_w(unsigned char input[64], unsigned int w[80])
{
  int i, j;
  unsigned int temp0, temp1;

  //前16轮计算，W(t)直接等于message block中的16个字（32-bit）。
  for (i=0; i<16; i++)
  {
    j = 4 * i;
    //按照大端模式，将数组input中的字节（8-bit）组成字（32-bit）后放到数组w中。
    w[i] = (input[j]<<24 | input[1+j]<<16 | input[2+j]<<8 | input[3+j]<<0); //|为按位或。
  }
  
  //后64轮计算。
  for (i=16; i<80; i++)
  {
    w[i] = (w[i-3] ^ w[i-8] ^ w[i-14] ^ w[i-16]); //^为按位异或。
    //如下3行代码实现将w[i]循环左移1位。
    temp0 = w[i]<<1;
    temp1 = w[i]>>31;
    w[i]= (temp0 | temp1);
  }

  for(i=0; i<80; i++)
  {
    //向w_log中写入w[i]，%08x：位宽为8，不足的用0补齐，以十六进制数形式输出整数。
    fprintf(w_log, "%08x\n", w[i]);
  }
}

//将有效数据长度len追加到message block中。
char append_len(int eff_data_len, char intput[64])
{
  unsigned int temp2, p1;
  int i, j;

  temp2 = 0;
  p1 = ~((~temp2)<<8);
  for(i=0; i<4; i++)
  {
    j = 8*i;
    intput[63-i] = (char)((eff_data_len&(p1<<j))>>j);
  }

  return '0';
}

//SHA1算法核心函数。
void sha1(unsigned char *input, unsigned int *res)
{
  //H0~H5的初始值。
  unsigned int H0 = 0x67452301, H1 = 0xefcdab89, H2 = 0x98badcfe, \
               H3 = 0x10325476, H4 = 0xc3d2e1f0;
  unsigned int A, B, C, D, E, temp0, temp1, temp2, temp3, k, f; //函数计算的中间变量。
  int eff_data_len; //有效数据长度。
  unsigned int w[80]; //接收生成的W(t)。
  int n, i, group;

  //char *表示一个指针变量，这个变量是可以被改变的。
  //const char *表示一个不会被改变的指针变量。
  n = strlen((const char *) input); //计算message block中的有效数据长度。

  if (n<=55)
  {
    //输入message block的末尾固定补一个0x80。
    input[n]= 0x80;
  
    //直到有效数据长度前的部分补0x80。
    for(i=n+1; i<60; i++)
    {
      input[i]=0x00;
    }

    //将有效数据长度len追加到message block中。
    eff_data_len = 8*n;
    append_len(eff_data_len, (char*)input);
  }
  else
  {
    printf("input message is too long, not supported in this model.\n");
    exit(1);
  }

  creat_w(input, w); //生成W(t)，t为计算的轮次。
  printf("\n");

  //准备好参与SHA1算法核心函数计算的数据后，开始80轮的计算。
  A = H0; B = H1; C = H2; D = H3; E = H4;
  for(i=0; i<80; i++)
  {
    group = i/20; //每20轮分一组。
    switch(group)
    {
      case 0: k = 0x5a827999; f = ((B&C) | (~B&D));        break;
      case 1: k = 0x6ed9eba1; f = (B^C^D);                 break;
      case 2: k = 0x8f1bbcdc; f = ((B&C) | (B&D) | (C&D)); break;
      case 3: k = 0xca62c1d6; f = (B^C^D);                 break;
    }
    //如下3行代码实现将A循环左移5位。
    temp1 = A<<5;
    temp2 = A>>27;
    temp3 = (temp1 | temp2);

    temp0 = temp3 + f + E + w[i] + k;
    E = D;
    D = C;
    
    //如下3行代码实现将A循环左移5位。
    temp1 = B<<30;
    temp2 = B>>2;
    C = (temp1 | temp2);

    B = A;
    A = temp0;
    
    //向h_log中写入A~E在每轮计算中的计算结果。
    //%08x：位宽为8，不足的用0补齐，以十六进制数形式输出整数。
    fprintf(h_log, "%08x%08x%08x%08x%08x\n", A, B, C, D, E);
  }
  
  //更新H0~H4，得到最终的160-bit的SHA1计算输出。
  //printf("H1:%x\n", H1);
  //printf("B :%x\n", B);
  H0 = H0 + A;
  H1 = H1 + B;
  H2 = H2 + C;
  H3 = H3 + D;
  H4 = H4 + E;
  //printf("H1:%x\n", H1);
  printf("output hash value:\n");
  //printf("%lx%lx%lx%lx%lx\n", H0, H1, H2, H3, H4); //%lx：以16进制输出长整型数据。
  printf("%08x%08x%08x%08x%08x\n", H0, H1, H2, H3, H4); //%08x：位宽为8，不足的用0补齐，以十六进制数形式输出整数。
  res[0] = H0; res[1] = H1; res[2] = H2; res[3] = H3; res[4] = H4;
}

//将input，即输入的message block写到din_fp中；将res，即输出的SHA计算结果写到dout_fp中。
void info_log (FILE *din_fp, FILE *dout_fp, unsigned char *input, unsigned int *res)
{
  int i;
  //C库函数size_t fwrite(const void *ptr, size_t size, size_t nmemb, FILE *stream)把ptr
  //所指向的数组中的数据写入到给定流stream中。
  //ptr：指向要被写入的元素数组的指针。
  //size：要被写入的每个元素的大小，以字节为单位。
  //nmemb：元素的个数，每个元素的大小为size字节。
  //stream：指向FILE对象的指针，该FILE对象指定了一个输出流。
  fwrite(input, sizeof(char), 64, din_fp);
  fwrite(res, sizeof(int), 5, dout_fp); //int的位宽为4个byte，故sizeof(int)的结果为4。
}

int main(int argc, char *argv[])
{
  unsigned char test0[64] = "abc"; //first byte in test0[0]
  unsigned char test1[64] = "a";
  unsigned char test2[64] = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnop"; //maximal byte lenght: 55 byte
  unsigned char test3[64] = "01234567012345670123456701234567";
  unsigned char test[64]; //first byte in test[0]

  unsigned char *input;
  unsigned int  res[5];
  unsigned char tmp;

  int i, len, cnt;

  FILE *din_fp, *dout_fp;

 //C库函数FILE *fopen(const char *filename, const char *mode)使用给定的模式mode打开
 //filename所指向的文件。
 //.bin文件用于在tb中与dut的输出作比对。
  din_fp  = fopen("./sha_in.bin", "wb"); //wb：创建一个用于写入的空文件，并以二进制方式写入。
  dout_fp = fopen("./sha_out.bin", "wb"); //记事本打开该二进制文件会乱码。

  w_log   = fopen("./w.log", "w"); //w：创建一个用于写入的空文件。
  h_log   = fopen("./h.log", "w"); //每一轮计算的W(t)和H0~H4都会被写入其中，一个message block计算80轮。
  
  printf("begin SHA-1 calculation:\n");

  //input，即输入的message block；res，即输出的SHA计算结果。
  //1：定向测试。
  printf("\n------ Orientation test: ------\n");
  input = test0;
  sha1(input, res);
  info_log(din_fp, dout_fp, input, res);
  
  input = test1;
  sha1(input, res);
  info_log(din_fp, dout_fp, input, res);
  
  input = test2;
  sha1(input, res);
  info_log(din_fp, dout_fp, input, res);
  
  input = test3;
  sha1(input, res);
  info_log(din_fp, dout_fp, input, res);

  //2：随机测试
  printf("\n------ random test: ------\n");
  for(cnt=0; cnt<100; cnt++) //100个随机测试case。
  {
    len = rand() % 56;
    if(len == 0) len = 1;
    
    //initial test with random data
    for(i=0; i<len; i++) {
      tmp = rand() % 256;
      if(tmp == 0)  tmp = 1;

      test[i] = tmp;
    }

    for(i= len; i<64; i++)
      test[i] = 0x00;

    input = test;
    sha1(input, res);
    info_log(din_fp, dout_fp, input, res);
  }

  //C库函数int fclose(FILE *stream)关闭流stream。刷新所有的缓冲区。
  fclose(din_fp);
  fclose(dout_fp);
  fclose(w_log);
  fclose(h_log);

  printf("SHA-1 calculation end:\n");

  //可以利用getch()函数让程序调试运行结束后等待编程者按下键盘才返回编辑界面，
  //使用getch()函数，需要先引入conio.h头文件。
  getch();
}