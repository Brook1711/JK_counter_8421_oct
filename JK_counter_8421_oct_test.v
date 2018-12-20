`timescale 1ns/1ns
module JK_counter_8421_oct_test(clk, rst, digit_seg, digit_cath);
input clk, rst;
output [7:0] digit_seg;
output [1:0] digit_cath;
wire Q3, Q2, Q1, Q0, clk_1;
wire Q7, Q6, Q5, Q4;
seg_scan decode(
	.clk_50M(clk),
	.rst_button(rst), 
	.switch({Q7, Q6, Q5, Q4 ,Q3,Q2,Q1,Q0}), 
	.digit_seg(digit_seg), 
	.digit_cath(digit_cath)
	);
frequency_divider #(.N(24999999)) u_clk_6(
	.clkin(clk),
	.clkout(clk_1)
	);
JK_counter_8421_oct u_counter(.clk(clk_1), .rst(rst), .Q3(Q3), .Q2(Q2), .Q1(Q1), .Q0(Q0));
JK_counter_8421_oct u_counter_(.clk(Q3), .rst(rst), .Q3(Q7), .Q2(Q6), .Q1(Q5), .Q0(Q4));
endmodule


module JK_counter_8421_oct(clk, rst, Q3, Q2, Q1, Q0);
input clk, rst;
output Q3, Q2, Q1, Q0;
wire [3:0] Q_temp;
wire [3:0] Q_temp_;
JK_flip_flop JK_0(
	.clk(~clk),
	.J(1),
	.K(1),
	.SD(1),
	.RD(~rst),
	.Q(Q_temp[0]),
	.Q_(Q_temp_[0])
	);
JK_flip_flop JK_1(
	.clk(~Q_temp[0]),
	.J(Q_temp_[3]),
	.K(1),
	.SD(1),
	.RD(~rst),
	.Q(Q_temp[1]),
	.Q_(Q_temp_[1])
	);
JK_flip_flop JK_2(
	.clk(~Q_temp[1]),
	.J(1),
	.K(1),
	.SD(1),
	.RD(~rst),
	.Q(Q_temp[2]),
	.Q_(Q_temp_[2])
	);
JK_flip_flop JK_3(
	.clk(~Q_temp[0]),
	.J(Q_temp[1] & Q_temp[2]),
	.K(1),
	.SD(1),
	.RD(~rst),
	.Q(Q_temp[3]),
	.Q_(Q_temp_[3])
	);
assign Q0 = Q_temp[0];
assign Q1 = Q_temp[1];
assign Q2 = Q_temp[2];
assign Q3 = Q_temp[3];
endmodule


module JK_flip_flop(clk, J, K, SD, RD, Q, Q_);
input clk, J, K, SD, RD;
output Q, Q_;

reg Q1;

wire clr;

assign clr = SD & RD;
assign judgez = SD|RD;
assign Q_ = ~Q1;

assign Q = Q1;

//assign Q_ = (SD^RD==1)? SD : ((SD == 1)? ~Q1:1'bz);

//assign Q = (SD^RD==1)? RD : ((SD == 1)? Q1:1'bz);


initial 
begin
	Q1=0;
end
always @(posedge clk or negedge clr or negedge judgez) begin
if (judgez==0) begin
	Q1<=1'bz;
end
else if (clr==0) begin
	Q1<=RD;
end

else begin
	if (J == 0 & K == 0) begin
			Q1<=Q1;
	end
	else if (J == 0 & K == 1) begin
			Q1<=0;
	end
	else if (J == 1 & K == 0) begin
			Q1<=1;
	end
	else if (J == 1 & K == 1) begin
			Q1<=!Q1;
	end
	else begin
			Q1<=Q1;
	end
end

end

endmodule

module seg_scan(clk_50M,rst_button, switch, digit_seg, digit_cath);
input clk_50M; //板载50M晶振
input rst_button;
input [7:0] switch;
output reg [7:0] digit_seg; //七段数码管的段选端
output [1:0] digit_cath; //2个数码管的片选端
wire reset; //复位按键
assign reset = rst_button;

//计数分频，通过读取32位计数器div_count不同位数的上升沿或下降沿来获得频率不同的时钟
reg [31:0] div_count;
always @(posedge clk_50M,posedge reset)
begin
    if(reset)
        div_count <= 0;   //如果按下复位按键，计数清零
    else
        div_count <= div_count + 1;
end

//拨码开关控制数码管显示，每4位拨码开关控制一个七段数码管
wire [7:0] digit_display;
assign digit_display = switch;

wire [3:0] digit;
always @(*)      //对所有信号敏感
begin
    case (digit)
        4'h0:  digit_seg <= 8'b11111100; //显示0~F
        4'h1:  digit_seg <= 8'b01100000;   
        4'h2:  digit_seg <= 8'b11011010;
        4'h3:  digit_seg <= 8'b11110010;
        4'h4:  digit_seg <= 8'b01100110;
        4'h5:  digit_seg <= 8'b10110110;
        4'h6:  digit_seg <= 8'b10111110;
        4'h7:  digit_seg <= 8'b11100000;
        4'h8:  digit_seg <= 8'b11111110;
        4'h9:  digit_seg <= 8'b11110110;
        4'hA:  digit_seg <= 8'b11101110;
        4'hB:  digit_seg <= 8'b00111110;
        4'hC:  digit_seg <= 8'b10011100;
        4'hD:  digit_seg <= 8'b01111010;
        4'hE:  digit_seg <= 8'b10011110;
        4'hF:  digit_seg <= 8'b10001110;
    endcase
end

//通过读取32位计数器的第10位的上升沿得到分频时钟，用于数码管的扫描
reg segcath_holdtime;
always @(posedge div_count[10], posedge reset)
begin
if(reset)
     segcath_holdtime <= 0;
else
     segcath_holdtime <= ~segcath_holdtime;
end

//7段数码管位选控制
assign digit_cath ={segcath_holdtime, ~segcath_holdtime};
// 相应位数码管段选信号控制
assign digit =segcath_holdtime ? digit_display[7:4] : digit_display[3:0];

endmodule

module frequency_divider(clkin, clkout);
parameter N = 1;
input clkin;
output reg clkout;
reg [27:0] cnt;
initial 
begin
cnt=0;
clkout<=0;
end
always @(posedge clkin) begin
	if (cnt==N) begin
		clkout <= !clkout;
		cnt <= 0;
	end
	else begin
		cnt <= cnt + 1;
	end
end
endmodule
