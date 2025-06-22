//
//  ContentView.swift
//  Visual Field
//
//  Created by Leo Li on 2025/6/19.
//

import SwiftUI
import RealityKit

struct ContentView : View {
    
    @StateObject private var magneticFieldManager = MagneticFieldManager()
    @StateObject private var dataCollection = MagneticFieldDataCollection()
    
    @State private var visualizationType: MagneticFieldVisualizer.VisualizationType = .vectors
    @State private var showControls = true
    @State private var visualizationEntities: [Entity] = []

    var body: some View {
        ZStack {
            RealityView { content in
                // 设置AR相机追踪
                content.camera = .spatialTracking
                
                // 创建世界坐标锚点
                let worldAnchor = AnchorEntity(.world)
                content.add(worldAnchor)
                
            } update: { content in
                // 更新可视化
                updateVisualization(content: content)
            }
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                magneticFieldManager.startTracking()
            }
            .onDisappear {
                magneticFieldManager.stopTracking()
            }
            
            // 控制界面
            if showControls {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            showControls.toggle()
                        }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                    
                    Spacer()
                    
                    ControlPanel(
                        magneticFieldManager: magneticFieldManager,
                        dataCollection: dataCollection,
                        visualizationType: $visualizationType
                    )
                }
            } else {
                VStack {
                    HStack {
                        Button(action: {
                            showControls.toggle()
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding()
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }
    
    /// 更新可视化
    private func updateVisualization(content: any RealityViewContentProtocol) {
        // 清除旧的可视化
        for entity in visualizationEntities {
            entity.removeFromParent()
        }
        visualizationEntities.removeAll()
        
        // 创建新的可视化
        guard !dataCollection.dataPoints.isEmpty else { return }
        
        let newEntities = MagneticFieldVisualizer.createVectorVisualization(
            for: dataCollection.dataPoints,
            type: visualizationType,
            scale: 1.0
        )
        
        // 添加到场景
        if let worldAnchor = content.entities.first {
            for entity in newEntities {
                worldAnchor.addChild(entity)
            }
            visualizationEntities = newEntities
        }
    }
}

#Preview {
    ContentView()
}
