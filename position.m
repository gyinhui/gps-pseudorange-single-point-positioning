%%
%gpsfileread
fid1=fopen('igs19962.sp3');%精密星历文件
fid2=fopen('sdwa1000.18o');%观测文件
fid3=fopen('BRDC1000.18p');%广播星历文件，未使用
fid4=fopen('position_data.txt','w');%定位结果输出
line_num=0;
tc=0;
times=zeros(96,1);
sp3p=zeros(96,32,4);
flag1=0;
while(1)
    line_txt=fgetl(fid1);
    line_num=line_num+1;
    if line_txt==-1
        break;
    end
    if line_txt(1)=='*'
        tc=tc+1;
        %时间仅限 18.4.10
        %times数组是顺序tc对应精密星历时间
        times(tc)=str2double(line_txt(15:16))*3600+str2double(line_txt(18:19))*60+str2double(line_txt(21:31));
        for s=1:32
            line_txt=fgetl(fid1);
            line_num=line_num+1;
            if line_txt==-1
                disp(['error: igs19962.sp3 unexcepted file end, line',num2str(line_num)]);
                flag1=1;
                break;
            end
            %sp3p数组是精密星历读取的内容
            %调用使用（时间编号，卫星编号，:)=【卫星坐标XYZ 卫星钟差】
            sp3p(tc,s,:)=[str2double(line_txt(5:18))*1000
                str2double(line_txt(19:32))*1000
                str2double(line_txt(33:46))*1000
                str2double(line_txt(47:60))/10^6];
        end
        if flag1==1
            break;
        end
    end
end
fclose(fid1);
line_num=0;
tc=0;
s=1;
timeo=zeros(2878,1);
os=cell(2878,1);
ot=zeros(2878,33);
while(1)
    line_txt=fgetl(fid2);
    line_num=line_num+1;
    if line_txt==-1
        break;
    end
    if line_txt(1)=='>'
        tc=tc+1;
        s=1;
        %time only for 18.4.10
        timeo数组是顺序tc对应观测时间
        timeo(tc)=str2double(line_txt(14:15))*3600+str2double(line_txt(17:18))*60+str2double(line_txt(20:29));
    end
    if line_txt(1)=='G'
        gpsnum=str2double(line_txt(2:3));
        if (32>=gpsnum)&&(gpsnum>=1)
            osa=[str2double(line_txt(6:17)),str2double(line_txt(22:33))];
            if(osa(1)~=0&&osa(2)~=0)
                %ot（1:32）存储可见卫星在观测值数组os内的位置，调用ot(gps卫星编号）=位置
                %ot（33）为可见卫星数
                ot(tc,33)=s;
                ot(tc,s)=gpsnum;
                %os是观测元胞数组，os{观测时间编号}（gps编号）=【C1C C2W观测量】
                %os大小不定，于可见卫星数有关
                os{tc}=[os{tc};osa];
                s=s+1;
            end
        end
    end
end
fclose(fid2);
fclose(fid3);
%%
%interp
%9阶拉格朗日插值
k=1;
int=cell(2878,1);
for i=1:length(timeo)
    if timeo(i)>times(k)
        if k<96
            k=k+1;
        end
    end
    if k<=5
        for j=1:ot(i,33)
            int{i}=[int{i};...
                [interp_lar(times(1:10),sp3p(1:10,ot(i,j),1),timeo(i)),...
                interp_lar(times(1:10),sp3p(1:10,ot(i,j),2),timeo(i)),...
                interp_lar(times(1:10),sp3p(1:10,ot(i,j),3),timeo(i)),...
                interp_lar(times(1:10),sp3p(1:10,ot(i,j),4),timeo(i))]];
        end
    elseif k>=91
        for j=1:ot(i,33)
            int{i}=[int{i};...
                interp_lar(times(end-9:end),sp3p(end-9:end,ot(i,j),1),timeo(i)),...
                interp_lar(times(end-9:end),sp3p(end-9:end,ot(i,j),2),timeo(i)),...
                interp_lar(times(end-9:end),sp3p(end-9:end,ot(i,j),3),timeo(i)),...
                interp_lar(times(end-9:end),sp3p(end-9:end,ot(i,j),4),timeo(i))];
        end
    else
        for j=1:ot(i,33)
            int{i}=[int{i};...
                interp_lar(times(k-4:k+5),sp3p(k-4:k+5,ot(i,j),1),timeo(i)),...
                interp_lar(times(k-4:k+5),sp3p(k-4:k+5,ot(i,j),2),timeo(i)),...
                interp_lar(times(k-4:k+5),sp3p(k-4:k+5,ot(i,j),3),timeo(i)),...
                interp_lar(times(k-4:k+5),sp3p(k-4:k+5,ot(i,j),4),timeo(i))];
        end
    end
end
%%
%position
%观测方程V=L-A*dX,P
%观测向量L,系数矩阵A
%当前历元坐标钟差int{Nnow}(gps)
%未知数向量X
%C1C频率f1，观测值os{Nnow}(1)
%C2W频率f2，观测值os{Nnow}(2)
%
f1=1575420000;
f2=1227600000;
c=299792458;
%Nnow=find(timeo==timetran(0,35,0));
X=[0,0,0,0];
pca=[f1^2/(f1^2-f2^2),f2^2/(f1^2-f2^2)];
fprintf(fid4,'\t\t\t  %s\t\t\t\t\t\t  %s\t\t\t\t\t\t  %s\n','X','Y','Z');
for Nnow=1:2877
    pcb=pca.*os{Nnow};
    pc=pcb(:,1)-pcb(:,2);
    adt=zeros(ot(Nnow,33),1)+1;%adt=zeros(ot(Nnow,33),1)+c;
    P=eye(ot(Nnow,33));
    X(4)=0;
    while(1)
        rho=sqrt(sum((int{Nnow}(:,1:3)-X(1:3)).^2,2));
        A=[(int{Nnow}(:,1:3)-X(1:3))./rho,adt];
        L=(pc-rho-X(4)+c*int{Nnow}(:,4));
        dX=(A'*P*A)\(A'*P*L);
        X=X-dX';
        if sqrt(sum(dX(1:3).^2))<0.000001
            break;
        end
    end
    [hour,minute,second]=timetran(timeo(Nnow));
    %disp([sprintf('18.04.10 %d:%d:%d',second,minute,hour) '   X=']);
    fprintf(fid4,'%2d:%2d:%2d\t  %19.12f\t  %19.12f\t  %19.12f\t\n',second,minute,hour,X(1),X(2),X(3));
    %disp(X);
    XX(Nnow,:)=X(1:3);
end
fclose(fid4);
winopen('position_data.txt');
%%
function [yy]=interp_lar(x,y,xx)
    order=length(x);
    if length(y)~=order
        yy=-Inf;
        return ;
    end
    x=reshape(x,1,order);
    y=reshape(y,1,order);
    m=xx-meshgrid(x);
    m=m-diag(diag(m))+eye(order);
    n=meshgrid(x(1:order))'-x(1:order)+eye(order);
    yy=sum(prod(m,2)./prod(n,2).*y');
end
%%
function [secondo,minuteo,houro]=timetran(second,minute,hour)
    if nargin==1
        houro=floor(second/3600);
        minuteo=floor(mod(second,3600)/60);
        secondo=mod(second,60);
    end
    if nargin==3
        secondo=hour*3600+minute*60+second;
    end
end

