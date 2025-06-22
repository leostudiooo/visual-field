# 项目配置说明

## 必要的权限配置

在 Xcode 项目的 Info.plist 中添加以下权限：

### 1. 相机权限 (ARKit 必需)
```xml
<key>NSCameraUsageDescription</key>
<string>此应用需要使用相机进行增强现实追踪，以在3D空间中可视化磁场数据。</string>
```

### 2. 运动和健身权限 (CoreMotion 磁力计)
```xml
<key>NSMotionUsageDescription</key>
<string>此应用需要访问设备的磁力计传感器来测量环境磁场强度和方向。</string>
```

## 项目设置

### 1. 部署目标
- 最低 iOS 版本: 17.0
- 设备要求: 支持 ARKit 的设备

### 2. 必需的 Capabilities
在 Xcode 项目设置中启用：
- ARKit
- Camera

### 3. 框架依赖
确保已链接以下框架：
- RealityKit
- ARKit
- CoreMotion
- SwiftUI

### 4. 构建设置
- Swift Language Version: Swift 5
- Architecture: arm64 (真机设备)

## 测试要求

### 设备要求
- iPhone 6s 或更新设备
- iOS 17.0 或更高版本
- 内置磁力计和陀螺仪
- 后置摄像头

### 测试环境
- 良好的光照条件
- 平坦的表面用于平面检测
- 远离强磁场干扰源

## 故障排除

### 常见问题
1. **AR 追踪失败**: 确保光照充足，移动设备以初始化追踪
2. **磁力计数据异常**: 远离电子设备和金属物体
3. **应用崩溃**: 检查权限是否正确配置

### 调试建议
1. 在真机上测试（模拟器不支持 ARKit 和磁力计）
2. 使用 Xcode 的 AR 调试工具查看追踪状态
3. 监控 CoreMotion 数据更新频率
