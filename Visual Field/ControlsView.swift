import SwiftUI

struct ControlsView: View {
    let isCollecting: Bool
    let hasData: Bool
    @Binding var showingARView: Bool // 保留但不使用，为了兼容性
    let onStartStopTapped: () -> Void
    let onClearData: () -> Void
    let onShowAnalysis: () -> Void
    
    var body: some View {
        VStack {
            // 顶部控制栏
            HStack {
                Spacer()
                
                // 数据分析按钮
                if hasData && !isCollecting {
                    Button(action: onShowAnalysis) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.green.opacity(0.8))
                            .clipShape(Circle())
                    }
                }
                
                // 清除数据按钮
                if hasData && !isCollecting {
                    Button(action: onClearData) {
                        Image(systemName: "trash")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Spacer()
            
            // 底部拍照样式的开始/停止按钮
            HStack {
                Spacer()
                
                VStack {
                    // 主拍照按钮
                    Button(action: onStartStopTapped) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .fill(isCollecting ? Color.red : Color.blue)
                                .frame(width: 60, height: 60)
                            
                            if isCollecting {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white)
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "location")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .scaleEffect(isCollecting ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isCollecting)
                    
                    // 状态文字
                    Text(isCollecting ? "停止采集" : (hasData ? "继续采集" : "开始采集"))
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
                
                Spacer()
            }
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ControlsView(
            isCollecting: false,
            hasData: false,
            showingARView: .constant(false),
            onStartStopTapped: {},
            onClearData: {},
            onShowAnalysis: {}
        )
    }
}
