import SwiftUI
import ARKit
import CoreMotion

struct ContentView: View {
    @StateObject private var fieldDataManager = FieldDataManager()
    @State private var showingAnalysis = false
    
    var body: some View {
        ZStack {
            // AR 相机视图 - 始终显示
            ARFieldRealTimeView(fieldDataManager: fieldDataManager)
                .ignoresSafeArea()
            
            // 数据展示叠层 - 移到右下角
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    // 根据状态显示不同内容
                    VStack {
                        if fieldDataManager.isCollecting {
                            // 正在采集状态
                            VStack(spacing: 15) {
                                Text("采集中...")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 2)
                                
                                if let currentReading = fieldDataManager.currentMagneticField {
                                    VStack(spacing: 8) {
                                        Text("磁场强度")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .shadow(color: .black, radius: 2)
                                        
                                        HStack(spacing: 15) {
                                            VStack {
                                                Text("X")
                                                    .font(.caption2)
                                                    .foregroundColor(.red)
                                                Text(String(format: "%.1f", currentReading.x))
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                            }
                                            
                                            VStack {
                                                Text("Y")
                                                    .font(.caption2)
                                                    .foregroundColor(.green)
                                                Text(String(format: "%.1f", currentReading.y))
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                            }
                                            
                                            VStack {
                                                Text("Z")
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                                Text(String(format: "%.1f", currentReading.z))
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        
                                        Text("μT")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                            .shadow(color: .black, radius: 2)
                                    }
                                }
                                
                                Text("数据点: \(fieldDataManager.collectedData.count)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 2)
                            }
                            .padding(12)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                            .frame(maxWidth: 180)
                            
                        } else if fieldDataManager.collectedData.isEmpty {
                            // 初始状态 - 不显示，让用户专注于AR
                            EmptyView()
                            
                        } else {
                            // 采集完成状态
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.green)
                                    .shadow(color: .black, radius: 2)
                                
                                Text("采集完成")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 2)
                                
                                Text("\(fieldDataManager.collectedData.count) 个数据点")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 2)
                                
                                Button(action: {
                                    showingAnalysis = true
                                }) {
                                    HStack {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                        Text("分析")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.8))
                                    .cornerRadius(6)
                                }
                            }
                            .padding(12)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                            .frame(maxWidth: 180)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 120) // 避免与底部控制栏重叠
                }
            }
            
            // 控制层
            ControlsView(
                isCollecting: fieldDataManager.isCollecting,
                hasData: !fieldDataManager.collectedData.isEmpty,
                showingARView: .constant(false), // 不再需要这个参数
                onStartStopTapped: {
                    if fieldDataManager.isCollecting {
                        fieldDataManager.stopCollecting()
                    } else {
                        fieldDataManager.startCollecting()
                    }
                },
                onClearData: {
                    fieldDataManager.clearData()
                },
                onShowAnalysis: {
                    showingAnalysis = true
                }
            )
        }
        .onAppear {
            fieldDataManager.requestPermissions()
        }
        .sheet(isPresented: $showingAnalysis) {
            FieldDataAnalysisView(fieldData: fieldDataManager.collectedData)
        }
    }
}

#Preview {
    ContentView()
}
