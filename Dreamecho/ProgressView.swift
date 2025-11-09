//
//  ProgressView.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import SwiftUI

struct DreamProgressView: View {
    let status: DreamStatus
    let progress: Double
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(
                        .secondary.opacity(0.3),
                        lineWidth: 6
                    )
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        .primary,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 32))
                    .foregroundStyle(.primary)
            }
            
            Text(status.rawValue)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text(message)
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .liquidGlassCard()
    }
    
    private var statusIcon: String {
        switch status {
        case .draft: return "doc.text"
        case .analyzing: return "brain.head.profile"
        case .analyzed: return "checkmark.circle"
        case .generating: return "sparkles"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
}

#Preview {
    DreamProgressView(
        status: .generating,
        progress: 0.6,
        message: "Generating 3D model..."
    )
    .padding()
    .liquidGlassBackground()
}
