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
            
            // 数据展示叠层
            VStack {
                Spacer()
                
                // 根据状态显示不同内容
                if fieldDataManager.isCollecting {
                    // 正在采集状态
                    VStack(spacing: 20) {
                        Text("正在采集磁场数据...")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2)
                        
                        if let currentReading = fieldDataManager.currentMagneticField {
                            VStack(spacing: 10) {
                                Text("当前磁场强度")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 2)
                                
                                HStack(spacing: 20) {
                                    VStack {
                                        Text("X")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                        Text(String(format: "%.2f", currentReading.x))
                                            .font(.title3)
                                            .foregroundColor(.red)
                                    }
                                    
                                    VStack {
                                        Text("Y")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                        Text(String(format: "%.2f", currentReading.y))
                                            .font(.title3)
                                            .foregroundColor(.green)
                                    }
                                    
                                    VStack {
                                        Text("Z")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                        Text(String(format: "%.2f", currentReading.z))
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                Text("μT")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 2)
                            }
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(10)
                        }
                        
                        Text("已采集: \(fieldDataManager.collectedData.count) 个数据点")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2)
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    
                } else if fieldDataManager.collectedData.isEmpty {
                    // 初始状态
                    VStack(spacing: 20) {
                        Image(systemName: "location.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 3)
                        
                        Text("Visual Field")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 3)
                        
                        Text("点击开始按钮采集空间磁场数据")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(15)
                    
                } else {
                    // 采集完成状态
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                            .shadow(color: .black, radius: 3)
                        
                        Text("采集完成")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 3)
                        
                        Text("共采集了 \(fieldDataManager.collectedData.count) 个磁场数据点")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2)
                        
                        Button(action: {
                            showingAnalysis = true
                        }) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                Text("数据分析")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(15)
                }
                
                Spacer()
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
