//
//  TestView.swift
//  EarthLord
//
//  Created by 赵云霞 on 2025/12/24.
//

import SwiftUI

struct TestView: View {
    var body: some View {
        ZStack {
            // 淡蓝色背景
            Color(red: 0.8, green: 0.9, blue: 1.0)
                .ignoresSafeArea()

            // 大标题
            VStack {
                Text("这里是分支宇宙的测试页")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.blue.opacity(0.7))
                    )
                    .shadow(radius: 10)
            }
        }
    }
}

#Preview {
    TestView()
}
