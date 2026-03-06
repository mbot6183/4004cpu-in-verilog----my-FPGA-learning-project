`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: HZ Sun
// 
// Create Date: 2026/03/02 21:02:19
// Design Name: 
// Module Name: EZcpu
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module EZcpu(
    input  wire       clk_50,
    input  wire       menu,
    input  wire       btn_return,
    input  wire       ok,
    input  wire       up, down, left, right,
    input  wire [7:0] sw,
    output reg  [7:0] led = 8'b11111111
);

    reg [6:0]  lst = 7'b0, llst = 7'b0, lllst = 7'b0;//按键状态寄存器，分别为当前、上一次、上上一次
    reg [3:0]  R [0:15];//寄存器，16个内置寄存器，每个4位
    reg [11:0] PC=12'b0;//程序计数器
    reg [7:0]  IR = 8'b0;//指令寄存器
    reg [7:0] OP1 = 8'b0;//指令第一字节暂存
    reg [7:0] OP2 = 8'b0;//指令第二字节暂存
    reg [1:0] state = 2'b0;//2字节指令执行状态
    reg [7:0] STACK [0:2];
    reg [1:0] sp = 8'b0;//栈指针
    reg [3:0] A = 4'b0;//累加寄存器
    reg C = 1'b0; //进位/借位标志
    reg IR_WE = 1'b0;
    reg [1:0] ram_bank=2'b0;
    integer i,j;

    always @(posedge clk_50) begin
        lst[6] <= menu;
        lst[5] <= btn_return;
        lst[4] <= ok;
        lst[3] <= up;
        lst[2] <= down;
        lst[1] <= left;
        lst[0] <= right;
        llst   <= lst;
        lllst  <= llst;
    end

    //按键冷却+去抖
    reg  [19:0] cd=20'd1000000;
    reg  [6:0]  key_pulse=7'b0;
    wire        cd_ok = (cd >= 20'd1000000);
    wire [6:0]  key_event = ~llst & lllst;   // 电位下降沿

    wire [3:0] Rr   = R[IR[3:0]];                 // 先声明 Rr
    wire [4:0] add5 = {1'b0,A} + {1'b0,Rr} + C;   // ADD：A + Rr + C
    wire [4:0] sub5 = {1'b0,A} + {1'b0,~Rr} + C;  // SUB(4004)：A + ~Rr + C
    wire daa_need = (A > 4'h9) || C; // BCD 调整需要：当 A 大于 9 或者有进位时
    wire [4:0] daa5   = {1'b0,A} + (daa_need ? 5'h06 : 5'h00); // DAA：如果需要调整则加 6，否则加 0

    always @(posedge clk_50) begin
        if (cd < 20'd1000000) begin
            cd <= cd + 20'b1;
        end
        if (cd_ok && (key_event != 7'b0)) begin
            key_pulse <= key_event;
            cd        <= 20'd0;
        end
        if (key_pulse != 7'b0) begin
            key_pulse <= 7'b0;
        end
        if (key_pulse[5]&&!IR_WE) begin//复位逻辑
            for (i = 0; i < 16; i = i + 1) begin
                R[i] <= 4'b0;
            end
            for (j = 0; i < 3; j = j + 1) begin
                STACK[j] <= 8'b0;
            end
            IR  <= 8'b00000000;
            OP2 <= 8'b00000000;
            PC <= 12'b0;//回到rom开头
            cd  <= 20'b0;
            led <= 8'b11111111;
            A <= 4'd0;
            C <= 1'b0;
            IR_WE <= 1'b0;
        end
        if (IR != 8'b0 && !IR_WE) begin//不输入指令时及时清除寄存器
            IR <= 8'b0;
        end
        //输入指令
        //按menu开始，OK结束
        if (key_pulse[6]) begin //MENU开始
            IR_WE <= 1'b1;
        end
        if (key_pulse[4]) begin //OK结束
            IR_WE <= 1'b0;
        end
        if(IR_WE) begin//输入中，LED亮为1，显示IR寄存器
            led <= ~IR; //LED低电平亮，所以取反来显示

            if (key_pulse[3]) begin //高电平
                IR[0] <= 1'b1;
            end

            if (key_pulse[2]) begin //低电平
                IR[0] <= 1'b0;
            end
        //左右移位
            if (key_pulse[1]) begin
                IR <= IR << 1'b1;
            end
            if (key_pulse[0]) begin
                IR <= IR >> 1'b1;
            end
        end
    if (!IR_WE) begin
        if(IR[7:4] == 4'hD) begin//装载立即数
            A <= IR[3:0];
            led <= {4'b1111,~IR[3:0]}; //显示立即数
        end
        if(IR[7:4] == 4'hA) begin//装载寄存器内容
            A <= Rr;
            led <= {4'b1111,~Rr}; //显示寄存器内容
        end
        if(IR[7:4] == 4'hB) begin//交换寄存器内容
            A <= Rr;
            R[IR[3:0]] <= A;
            led <= {~Rr,~A}; //显示寄存器内容
        end
        if(IR[7:4] == 4'h6) begin//寄存器加1
            R[IR[3:0]] <= Rr+1;
            led <= {4'b1111,~(Rr+1)}; //显示寄存器内容
        end
        if(IR[7:4] == 4'h8) begin//加法，A+Rr+C
            A <= add5[3:0];
            C <= add5[4];
            led <= {4'b1111, ~add5[3:0]}; //显示加法结果
        end
        if(IR[7:4] == 4'h9) begin//减法，A+~Rr+C
            A <= sub5[3:0];
            C <= sub5[4];
            led <= {4'b1111, ~sub5[3:0]}; //显示减法结果
        end
        if(IR[7:4] == 4'hF) begin
            if(IR[3:0] == 4'h0) begin//清零A和C
                A <= 4'b0;
                C <= 1'b0;
                led <= 8'b11111111; //显示全灭
            end
            if(IR[3:0] == 4'h1) begin//清零进位
                C <= 1'b0;
                led <= 8'b11111111; //显示全灭
            end
            if(IR[3:0] == 4'hA) begin//置位进位
                C <= 1'b1;
                led <= 8'b11111110; //显示C进位为1
            end
            if(IR[3:0] == 4'h2) begin//加法寄存器+1
                A <= A +1;
                C <= (A == 4'b1111) ? 1'b1 : 1'b0;//如果A加1后溢出，置位进位
                led <= {4'b1111,~(A + 1)}; //显示加法结果
            end
            if(IR[3:0] == 4'h4) begin//按位取反
                A <= ~A;
                led <= {4'b1111,A}; //显示取反结果
            end
            if(IR[3:0] == 4'h3) begin//进位取反
                C <= ~C;
                led <= {7'b0,C}; //显示C的取反结果
            end
            if(IR[3:0] == 4'h5) begin//带进位的循环左移
                A[3:1] <= A[2:0];
                A[0] <= C;
                C <= A[3];
                led    <= {4'b1111, ~{A[2:0], C}};   // 显示 RAL 后的新 A 寄存器//显示循环左移结果
            end
            if(IR[3:0] == 4'h6) begin//带进位的循环右移
                A[2:0] <= A[3:1];
                A[3] <= C;
                C <= A[0];
                led    <= {4'b1111, ~{C, A[3:1]}};   // 显示 RAR 后的新 A 寄存器//显示循环右移结果
            end
            if(IR[3:0] == 4'h7) begin//把C移入A，清空C
                A[3:1] <= 3'b0;
                A[0] <= C;
                C <= 1'b0;
                led    <= {4'b1111, ~{3'b0, C}};
            end
            if(IR[3:0] == 4'h8) begin//A减1
                A <= A - 1'b1;
                C <= (A == 4'b0000) ? 1'b0 : 1'b1;//如果A减1后溢出，清零进位
                led <= {4'b1111,~(A - 1)}; //显示减法结果
            end
            if(IR[3:0] == 4'h9) begin//
            A <= (C ? 4'hA : 4'h9);
            C <= 1'b0;
            led <= {4'b1111,~(C ? 4'hA : 4'h9)}; //显示结果
            end
            if(IR[3:0] == 4'hB) begin//DAA十进制转换加法寄存器A
            A <= daa5[3:0];
            C <= daa5[4] | C;
            led <= {4'b1111,~daa5[3:0]}; //显示DAA结果
            end
            if(IR[3:0] == 4'hC) begin//键盘码转换
            case (A)//第几位拉高则变为二进制几
            4'b0000: A <= 4'b0000;
            4'b0001: A <= 4'b0001;
            4'b0010: A <= 4'b0010;
            4'b0100: A <= 4'b0011;
            4'b1000: A <= 4'b0100;
            default: A <= 4'hF;
            endcase
            end
            if(IR[3:0] == 4'hD) begin//选择RAM Bank
            ram_bank <= A[1:0]; // 选择 RAM Bank，A 的低两位决定选择哪个 Bank
            end

    end
    end
    end

endmodule
