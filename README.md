# 在示波器上播放 Bad Apple!!

输入一个视频，输出其二值化后边缘点的坐标组成的波形文件

左声道：水平坐标

右声道：垂直坐标

[无法加载图片点这里](https://blog.csdn.net/qq_23204557/article/details/105934126 "GitHub的raw.githubusercontent.com的DNS被污染，修改Hosts解决")

![badapple_hot](https://raw.githubusercontent.com/chdilo/pictures/master/img/badapple_hot.png)

## MATLAB脚本的详细过程

脚本中预设的每帧扫描次数`scanNumPF`为 2 次（示波器的光点在屏幕上画 2 次，且原视频帧率为 20 帧，这样输出的波形基频为 2×20 = 40 Hz，避免音频设备在听域范围外的衰减），输出音频采样率`Fs`为 48 kHz（采样位数为默认的 16 位，这是完全足够的，而图像越复杂时采样率越高越好）。

```matlab
scanNumPF = 2; % 每帧扫描次数
Fs = 48e3; % 采样率
```

选择输入的视频文件和输出的波形文件，得到文件名和路径名。

```matlab
[vidFile, vidPath] = uigetfile('*.avi;*.mp4', '选择视频文件', '22118703_5_0.mp4');
[wavFile, wavPath] = uiputfile({'*.wav';'*.flac'}, '保存音频文件', 'PlayMe');
```

### 读取视频文件

首先创建`VideoReader`对象`Vid`，用于读取原视频数据。

```matlab
Vid = VideoReader([vidPath vidFile]);
```

读取原视频的部分信息

```matlab
vidFrameRate = Vid.FrameRate; % 帧率
nFrames = Vid.NumFrames; % 总帧数
vidHeight = Vid.Height; % 高度
vidWidth = Vid.Width; % 宽度
```

算出每帧图像的采样点数`dotNumPF`和示波器的光点在屏幕上每画 1 次的采样点数`dotNum`

```matlab
dotNumPF = Fs/vidFrameRate; % 每帧点数
dotNum = dotNumPF/scanNumPF; % 每次扫描点数
```

### 读取帧并处理

接着一帧一帧读取图像

```matlab
while hasFrame(Vid)
    vidFrame = readFrame(Vid); % 读取每帧图像
```

以原视频 56 秒处为例

![badapple_1](https://raw.githubusercontent.com/chdilo/pictures/master/img/badapple_1.png "56 秒处原视频帧")

读取的图像数据类型为`uint8`的 RGB 图像，即由范围在 [0, 255] 的整数值组成的 360×480×3 的三维矩阵。将其值转为范围在 [0, 1] 的双精度值以用于计算。

```matlab
vidFrame = im2double(vidFrame);
```

![badapple_2_2](https://raw.githubusercontent.com/chdilo/pictures/master/img/badapple_2_2.png "uint8 转 double")

转换为灰度图，即 360 行，480 列的二维矩阵

```matlab
vidFrame = rgb2gray(vidFrame);
```

![badapple_2_3](https://raw.githubusercontent.com/chdilo/pictures/master/img/badapple_2_3.png "转为灰度图")

高斯滤波，其中标准差与视频宽度成正比（适应图像尺寸），与每次扫描点数成反比（根据采样点数简化图形，采样点越多，需要简化的越少），二值化

```matlab
vidFrame = imgaussfilt(vidFrame, vidWidth/dotNum) >= 0.5; % 滤波
```

![badapple_3](https://raw.githubusercontent.com/chdilo/pictures/master/img/badapple_3.png "采样率为 48kHz 时的滤波结果")

Canny算子边缘检测，得到边缘的线条

```matlab
vidFrame = edge(double(vidFrame), 'Canny'); % 边缘检测
```

![badapple_5](https://raw.githubusercontent.com/chdilo/pictures/master/img/badapple_5.png "边缘检测的结果")

再跟踪边缘的线条的边界，得到边界坐标，存放在元胞数组`Bou`中。元胞的个数等于线条的数量，一个元胞中的坐标连起来近似于沿着一条边缘的线条上走一个来回。

```matlab
Bou = bwboundaries(vidFrame); % 获取边界坐标
```

![badapple_6](https://raw.githubusercontent.com/chdilo/pictures/master/img/badapple_6.png "图像中的线条")

直接将获取的坐标首尾相接并不合适，这些线条的顺序不合理，画完一条线画下一条时，跨越的距离可能很长，显示在示波器上的杂乱线条更加明显

![badapple_7](https://raw.githubusercontent.com/chdilo/pictures/master/img/badapple_7.png "多余的线条")

也会使波形中的跳变幅度增大，产生更多的高频成分。

![badapple_9](https://raw.githubusercontent.com/chdilo/pictures/master/img/badapple_9.png "多余的跳变")

所以可以优化一下线条的顺序

```flow
st=>start: 开始
op1=>operation: 获取线条数量
op2=>operation: 初始化输出
cond1=>condition: j<=线条数
op3=>operation: 获取剩余未排序线条数
op4=>operation: 初始化距离列表dist
cond2=>condition: i<=剩余线条数
op5=>operation: 获取第i条线的第一个点的坐标p1
op6=>operation: 计算p0到p1的距离，放入dist(i)
op7=>operation: 找到距离列表dist中最小值的位置indx
op8=>operation: 将对应位置的线条Bou{indx}放入BouTemp{j}
op9=>operation: 获取这条线的最后一个点的坐标p0
op10=>operation: 将这条线从原线条中删除
op11=>operation: 将排好序的线条连成一串
e=>end: 结束

st->op1->op2->cond1
cond1(yes)->op3
cond1(no)->op11
op3->op4->cond2
cond2(yes)->op5
cond2(no)->op7
op5->op6->cond2
op7->op8->op9->op10->cond1
op11->e
```

```matlab
bouNum = length(Bou);
BouTemp = cell(bouNum, 1);
for j = 1:bouNum
    bouNumLeft = length(Bou);
    dist = zeros(bouNumLeft, 1);
    for i = 1:bouNumLeft
        p1 = Bou{i}(1,:);
        dist(i) = norm(p0-p1);
    end
    [~, indx] = min(dist);
    BouTemp{j} = Bou{indx};
    p0 = Bou{indx}(end,:);
    Bou(indx) = [];
end
bouDot = cell2mat(BouTemp); % 边界上的每一点
```

一般来说，排序后多余的连线会更短

![badapple_8](https://raw.githubusercontent.com/chdilo/pictures/master/img/badapple_8.png)

并减少多余的跳变

![badapple_10](https://raw.githubusercontent.com/chdilo/pictures/master/img/badapple_10.png)

将排好序的线条坐标连成一串后，统计坐标点的数量`bouDotNum`。如果大于 0 ，将坐标点数重采样到`dotNum`个，然后重复`scanNumPF`次。如果等于 0 ，说明无画面内容，全部填充 NaN 。

```matlab
bouDotNum = length(bouDot); % 每一帧点的数量
if bouDotNum > 0
    bouDot = resample(bouDot, dotNum, bouDotNum, 0); % 调整点数
    bouDotTemp = repmat(bouDot, scanNumPF, 1); % 每帧重复扫描scanNumPF次
else
    bouDotTemp = NaN(dotNumPF, 2); % 无画面
end
```

为了在跳变处不产生中间值，重采样的方法为最近邻法

![badapple_11](https://raw.githubusercontent.com/chdilo/pictures/master/img/badapple_11.png "重采样的方法")

将这一帧所有坐标点放入`bouDotxy{k}`

```matlab
bouDotxy{k} = bouDotTemp; % 所有要描的点的坐标
```

处理完所有的视频帧后，将所有帧的坐标连成一串

```matlab
bouDotxy = cell2mat(bouDotxy);
```

移除直流

```matlab
bouDotxy = bouDotxy - mean(bouDotxy, 'omitnan'); % 移除直流
```

归一化，将数值调整到 [-1, 1] 的范围

```matlab
bouDotxy = bouDotxy / max(abs(bouDotxy),[],'all'); % 归一化
```

调整画面方向

```matlab
% 顺时针旋转90°
bouDotxy(:,1) = -bouDotxy(:,1); % 水平翻转
bouDotxy(:,[1 2]) = bouDotxy(:,[2 1]); % 交换xy
```

将无数值的点替换为 0 

```matlab
% 无画面的点
bouDotxy(isnan(bouDotxy)) = 0;
```

输出结果

![badapple_13](https://raw.githubusercontent.com/chdilo/pictures/master/img/badapple_13.png)

## 硬件连接

将示波器视图设置为 X-Y 模式，连接如下

![badapple_14](https://raw.githubusercontent.com/chdilo/pictures/master/img/badapple_14.png "硬件连接")

如果正确，以下音频将显示校准圆

```matlab
d = 60;
fs = 48e3;
ts = 1/fs;
t = 0:ts:d-ts;
x = cospi(500*2*t);
y = sinpi(500*2*t);
test = [x' y'];
audiowrite('校准圆.wav',test,fs)
```

![badapple_15](https://raw.githubusercontent.com/chdilo/pictures/master/img/badapple_15.png)

![badapple_16](https://raw.githubusercontent.com/chdilo/pictures/master/img/badapple_16.gif)