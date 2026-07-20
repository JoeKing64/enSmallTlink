# 本项目旨在缩小Mac端Tlink App的图标大小
缩小到原来的78%，使其和别的App站一排时候不会更大

## 核心逻辑
解包 /Applications/Tlink.app/Contents/Resources/icon.icns  里面的一组png，将其缩小到原来的78%，重新打包后再替换
如果运行时候有问题可以看看按照这个思路自己写脚本，或者手动修改到更精确的尺寸
希望下个版本更新就能修复这个问题

>作者还没入职，在雏鹰训练营连着羸弱的随身WiFi给公司代码修Bug....

## 使用方法：
1.下载 [enSmallTlink.sh](./enSmallTlink.sh) 放到桌面；

2.打开「终端」，输入授权命令：
```bash
chmod +x ~/Desktop/enSmallTlink.sh
```
3.在「终端」，输入命令执行脚本：
```bash
~/Desktop/enSmallTlink.sh
```
4.中途会要求输入电脑开机密码（输入时屏幕不显示字符，正常输完回车）

## 还原方法：
1.下载 [reLargeTlink.sh](./reLargeTlink.sh) 放到桌面；

2.打开「终端」，输入授权命令：
```bash
chmod +x ~/Desktop/reLargeTlink.sh
```
3.在「终端」，输入命令执行脚本：
```bash
~/Desktop/reLargeTlink.sh
```
4.中途会要求输入电脑开机密码（输入时屏幕不显示字符，正常输完回车）
