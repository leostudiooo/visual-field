//
//  MagneticFieldManager.swift
//  Visual Field
//
//  Created by Leo Li on 2025/6/19.
//

import Foundation
import CoreMotion
import ARKit
import Combine

/// 磁场数据管理器
class MagneticFieldManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private let arSession = ARSession()
    
    @Published var currentMagneticField: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    @Published var currentPosition: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    @Published var isTracking: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupMotionManager()
        setupARSession()
    }
    
    /// 设置运动管理器
    private func setupMotionManager() {
        guard motionManager.isMagnetometerAvailable else {
            print("磁力计不可用")
            return
        }
        
        motionManager.magnetometerUpdateInterval = 0.1 // 10Hz更新频率
    }
    
    /// 设置AR会话
    private func setupARSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arSession.run(configuration)
    }
    
    /// 开始追踪
    func startTracking() {
        guard !isTracking else { return }
        
        isTracking = true
        
        // 开始磁力计数据更新
        motionManager.startMagnetometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            
            // 转换磁场数据到微特斯拉单位并更新
            let magneticField = SIMD3<Float>(
                Float(data.magneticField.x * 1_000_000), // 转换为µT
                Float(data.magneticField.y * 1_000_000),
                Float(data.magneticField.z * 1_000_000)
            )
            
            DispatchQueue.main.async {
                self.currentMagneticField = magneticField
            }
        }
        
        // 监听AR会话更新
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateCurrentPosition()
            }
            .store(in: &cancellables)
    }
    
    /// 停止追踪
    func stopTracking() {
        isTracking = false
        motionManager.stopMagnetometerUpdates()
        cancellables.removeAll()
    }
    
    /// 更新当前位置
    private func updateCurrentPosition() {
        guard let frame = arSession.currentFrame else { return }
        
        let transform = frame.camera.transform
        let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        
        DispatchQueue.main.async {
            self.currentPosition = position
        }
    }
    
    /// 获取当前数据点
    func getCurrentDataPoint() -> MagneticFieldDataPoint? {
        guard isTracking else { return nil }
        return MagneticFieldDataPoint(position: currentPosition, magneticField: currentMagneticField)
    }
    
    deinit {
        stopTracking()
    }
}
