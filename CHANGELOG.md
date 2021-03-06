*其他语言版本: [English](CHANGELOG.en-us.md), [简体中文](CHANGELOG.md).*

# v3.0.2(2020-1-8)
## 修复
- 修复 `MSVDraft.timeRange` 在导出阶段不生效的问题。

# v3.0.1(2019-12-2)
## 功能
- 编辑器支持内置美颜特效。
## 修复
- 修复 `MSVLUTFilterEditorEffect` 和 `MSVImageStickerEditorEffect` 的 `image` 属性为 nil 可能引起 crash 的问题。
## 其他
- 重构渲染管线部分代码。

# v3.0.0(2019-11-4)
## 功能
- 添加动态贴纸支持。
- `MSVClip` 支持生成快照。
- `MSVClip` 支持获取 `originalDuration`、`originalDurationAtMainTrack`、`size` 和 `frameRate` 参数。
- `MSVEditor` 支持直接使用 `graffitiManager` 添加涂鸦。
- `MSVEditor` 添加 `displayingRect`
- `MSVExporter` 支持 `reverseVideo` 参数用于生成倒放视频。
- `MSVGraffitiView` 添加 `displayingRect` 参数及 `-exportAsImageStickerEditorEffect` 方法。
## 其它
- 部分接口重构，具体参考 [v2.x.x 到 v3.x.x 迁移指南](v2.x.x to v3.x.x transfer guide.md)

# v2.2.21(2019-10-31)
## 功能
- 添加 `MSVExporter.maxKeyFrameInterval` 属性用于指定最大关键帧间隔。
- 添加 `MSVRecorder.finishiing` 以便检查当前是否处于正在停止拍摄的状态。
## 修复
- 修复在 `-finishRecordingWithCompletionHandler:` 还未完成时再次调用 `-startRecordingWithError:`、`-startRecordingWithClipConfiguration:error:` 或 `-finishRecordingWithCompletionHandler:` 可能发生未知错误却不返回错误的问题。
- 修复 `-snapshotWithCompletion:` 方法可能不回调的问题。

# v2.2.20(2019-8-27)
## 修复
- 修复 XCode 10 及以下无法编译通过 framework 的问题。

# v2.2.19(2019-8-27)
## 修复
- 修复部分组件在后台获取 UI 参数的问题。
- 修复导出纯音频资源失败的问题。

# v2.2.18(2019-9-15)
## 功能
- 将 `MovieousBase` 升级到 v1.1.6。
    - 增加 `averagePowerLevel` 属性。
## 修复
- 修复录制器偶现的编码失败问题。
- 更新鉴权机制，鉴权失败不再抛 exception。
- 将 `MSVRecorder.currentClipDuration` 细化为 `MSVRecorder.currentClipOriginalDuration` 和 `MSVRecorder.currentClipRealDuration`。
- 修复 `MSVRecorder` 配置背景音乐时可能出现音乐长度异常的问题。
- 修复 `cancelRecording` 等操作后背景音乐的进度未更新的问题。

# v2.2.17(2019-8-26)
## 功能
- 将 `MovieousBase` 升级到 v1.1.5。
    - 修复导出视频颜色异常的问题。
## 优化
- 提升音量调节灵敏度。
## 修复
- 修复在自带旋转的视频中 `MSVDraft.videoSize` 获取异常的问题。

# v2.2.16(2019-8-22)
## 功能
- 允许 `MSVClip` 及其子类的 `volume` 属性大于1。

# v2.2.15(2019-8-1)
## 功能
- 给 `MSVGifGenerator` 增加 `loopCount` 参数调整播放次数。
## 修复
- 修复 `MSVImageGeneratorResult` 的 `timeRange` 参数应用不成功的问题。

# v2.2.14(2019-7-27)
## 修复
- 修复 `MSVImageGenerator` 释放时可能出现 crash 的问题。

# v2.2.13(2019-7-23)
## 修复
- 修复自动生成的 gif 路径扩展名错误的问题。

# v2.2.12(2019-7-16)
## 功能
- 将 `MovieousBase` 升级到 v1.1.1。
- 支持切换摄像头时模糊化过渡。
- gif 生成支持。
## 优化
- 优化默认的拍摄文件，导出文件等的存储路径。

# v2.2.11(2019-7-9)
## 功能
- `MSVRecorder` 支持 `m4a` 类型录制
## 修复
- 修复 `MSVRecorder` 回调的当前片段时长不正确的问题。
- 减少 `MSVRecorder` 录制过程中频繁报错的情况。
- 修复 `MSVRecorder` 在调用 `stopCapturing` 方法后调用其他方法可能被卡住的问题。 

# v2.2.10(2019-6-30)
## 修复
- 修复 `MSVRecorder` 使用过程中 `MSVCamera` 内存泄露的问题。
- 修复 `-switchCamera` 时可能出现旋转方向不正确的图像的问题。
- 修复 `MSVRecorder` 在录制过程中经常报错的问题。

# v2.2.9(2019-5-16)
## 修复
- 修复 `-updateDraft:error:` 使用新的资源可能导致视频无法刷新的问题。
- 修复 `MSVRecorder` 在 `-dealloc` 时可能发生 crash 的问题。
- 修复 `MSVRecorder` 在发生错误后未正确恢复状态的问题。

# v2.2.8(2019-5-14)
## 修复
- 修复  `-updateDraft:error:` 可能导致 `editor` 无法正常播放视频的问题。

# v2.2.7(2019-5-14)
## 修复
- 修复释放对象时有可能触发 crash 的问题。
- 修复偶现的音量同步问题。
- 修复 `-seekToTime:accurate:` 时间基准未添加 `timeRange` 影响的问题。

# v2.2.6(2019-5-7)
## 修复
- 修复 `-startCapturingWithCompletion` 调用时会短暂卡住主线程的问题。

# v2.2.5(2019-5-5)
## 修复
- 修复 `preferredVideoOrientation` 在切换摄像头之后不生效的问题。

# v2.2.4(2019-5-4)
## 修复
- 修复 `-snapshotWithCompletion:` 接口可能发生 timeout 的错误。
- 优化编码器。

# v2.2.3(2019-4-29)
## 功能
- 使用 `AVCaptureStillImageOutput` 来生成录制器的快照。
- 录制器添加 `flashMode` 属性。
## 修复
- 修复图片处理管道中 `videoSize` 转向的问题。

# v2.2.2(2019-4-28)
## 功能
- 给 `MSVEditor` 添加 `volume` 属性。

# v2.2.1(2019-4-25)
## 其他
- 更新头文件文档。

# v2.2.0(2019-4-24)
## 功能
- 添加 `MSVDraft.videoSize` 设置的错误返回。
- 将更多的摄像头和麦克风配置项加入 `MSVRecorderAudioConfiguration` 和 `MSVRecorderVideoConfiguration` 中。
## 修复
- 修复 `MSVDraft` 进行 `-copy` 时会 crash 的问题。
## 其他
- 将 `MSVVideoExporter` 重命名为 `MSVExporter`。
- 将 `MSVRecorderVideoConfiguration.scalingMode` 重命名为 `MSVRecorderVideoConfiguration.previewScalingMode`。

# v2.1.0(2019-4-15)
## 功能
- 将 `MSVAudioClip` 和 `MSVVideoClip` 合并为 `MSVMixTrackClip`。
- 添加 `MSVAuthentication` 来对 SDK 进行授权。
- 添加 `MSVImageGenerator` 来管理视频快照。
- 给 `MSVRecorder` 添加内置美颜和其他滤镜。
- 添加包括曝光模式，手电筒模式等更多的摄像头控制操作。
- 给 `MSVTimeEffect` 添加 `scope` 配置项。

# v2.0.1(2019-3-21)
## 功能
- 添加涂鸦功能。

# v2.0.0(2019-3-19)
## 功能
- 添加大小、位置、旋转方向、背景颜色等配置项到 `MSVMainTrackClip` 中
- 添加视频混合功能。
- 将 `effects` 分为 `basicEffects` 和 `timeEffects`。
- 给 `MSVEditor` 添加当前播放位置的通知。
- 重命名部分接口。
- `MSVRecorder` 中移除多长录制时长配置项，你可以实现自己的录制时长控制逻辑来实现录制时长控制。
## 修复
- 修复视频旋转的 bug。

# v1.0.3(2019-1-15)
## 功能
- 修复视频转向的 bug。

# v1.0.2(2018-12-27)
## 其他
- 重命名 `MSVImagePasterEffect` 为 `MSVImageStickerEffect`。
- 接口文档调整为英文版。

# v1.0.1(2018-12-3)
## 功能
- 添加鉴权支持。
## 修复
- 修复频繁切换背景音乐等操作可能导致的音频服务被重置，无法正常预览的问题。

# v1.0.0(2018-11-28)
- 发布初版。
