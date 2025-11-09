//
//  ToggleImmersiveSpaceButton.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import SwiftUI

struct ToggleImmersiveSpaceButton: View {

    @Environment(AppModel.self) private var appModel

    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    var body: some View {
        Button {
            Task { @MainActor in
                // 防止重复操作
                guard appModel.immersiveSpaceState != .inTransition else { return }
                
                switch appModel.immersiveSpaceState {
                    case .open:
                        appModel.immersiveSpaceState = .inTransition
                        await dismissImmersiveSpace()
                        // 状态会在 ImmersiveView.onDisappear() 中更新为 .closed

                    case .closed:
                        appModel.immersiveSpaceState = .inTransition
                        switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
                            case .opened:
                                // 状态会在 ImmersiveView.onAppear() 中更新为 .open
                                break

                            case .userCancelled, .error:
                                // 打开失败，恢复为关闭状态
                                appModel.immersiveSpaceState = .closed
                                
                            @unknown default:
                                // 未知响应，假设空间未打开
                                appModel.immersiveSpaceState = .closed
                        }

                    case .inTransition:
                        // 不应该到达这里，因为按钮已被禁用
                        break
                }
            }
        } label: {
            Text(appModel.immersiveSpaceState == .open ? "Hide Immersive Space" : "Show Immersive Space")
        }
        .disabled(appModel.immersiveSpaceState == .inTransition)
        .animation(.none, value: 0)
        .fontWeight(.semibold)
    }
}
