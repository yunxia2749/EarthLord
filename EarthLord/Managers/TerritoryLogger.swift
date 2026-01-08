//
//  TerritoryLogger.swift
//  EarthLord
//
//  圈地功能日志管理器：在App内显示调试日志，方便真机测试
//

import Foundation
import SwiftUI
import Combine

// MARK: - LogType
/// 日志类型
enum LogType: String {
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"

    /// 对应的颜色
    var color: Color {
        switch self {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

// MARK: - LogEntry
/// 日志条目
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogType
}

// MARK: - TerritoryLogger
/// 圈地日志管理器（单例 + ObservableObject）
class TerritoryLogger: ObservableObject {

    // MARK: - Singleton

    static let shared = TerritoryLogger()

    private init() {}

    // MARK: - Published Properties

    /// 日志数组
    @Published var logs: [LogEntry] = []

    /// 格式化的日志文本（用于显示）
    @Published var logText: String = ""

    // MARK: - Private Properties

    /// 最大日志条数（防止内存溢出）
    private let maxLogCount = 200

    /// 时间格式化器（显示用）
    private let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    /// 时间格式化器（导出用）
    private let exportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    // MARK: - Public Methods

    /// 添加日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - type: 日志类型
    func log(_ message: String, type: LogType = .info) {
        // 确保在主线程更新
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 创建日志条目
            let entry = LogEntry(timestamp: Date(), message: message, type: type)

            // 添加到数组
            self.logs.append(entry)

            // 限制最大条数
            if self.logs.count > self.maxLogCount {
                self.logs.removeFirst()
            }

            // 更新格式化文本
            self.updateLogText()
        }
    }

    /// 清空所有日志
    func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.logs.removeAll()
            self?.logText = ""
        }
    }

    /// 导出日志为文本
    /// - Returns: 格式化的日志文本
    func export() -> String {
        let header = """
        === 圈地功能测试日志 ===
        导出时间: \(exportFormatter.string(from: Date()))
        日志条数: \(logs.count)

        """

        let logLines = logs.map { entry in
            let time = exportFormatter.string(from: entry.timestamp)
            return "[\(time)] [\(entry.type.rawValue)] \(entry.message)"
        }

        return header + logLines.joined(separator: "\n")
    }

    // MARK: - Private Methods

    /// 更新格式化的日志文本
    private func updateLogText() {
        logText = logs.map { entry in
            let time = displayFormatter.string(from: entry.timestamp)
            return "[\(time)] [\(entry.type.rawValue)] \(entry.message)"
        }.joined(separator: "\n")
    }
}
