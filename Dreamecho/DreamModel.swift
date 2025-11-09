//
//  DreamModel.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import Foundation

struct Dream: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var createdAt: Date
    var status: DreamStatus
    var statusUpdatedAt: Date?
    var analysis: DreamAnalysis?
    var modelURL: String?
    var keywords: [String]
    var emotions: [String]
    var symbols: [String]
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case createdAt
        case status
        case statusUpdatedAt
        case analysis
        case modelURL
        case keywords
        case emotions
        case symbols
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        createdAt: Date = Date(),
        status: DreamStatus = .draft,
        statusUpdatedAt: Date? = Date(),
        analysis: DreamAnalysis? = nil,
        modelURL: String? = nil,
        keywords: [String] = [],
        emotions: [String] = [],
        symbols: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.createdAt = createdAt
        self.status = status
        self.statusUpdatedAt = statusUpdatedAt
        self.analysis = analysis
        self.modelURL = modelURL
        self.keywords = keywords
        self.emotions = emotions
        self.symbols = symbols
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        status = try container.decode(DreamStatus.self, forKey: .status)
        statusUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .statusUpdatedAt)
        analysis = try container.decodeIfPresent(DreamAnalysis.self, forKey: .analysis)
        modelURL = try container.decodeIfPresent(String.self, forKey: .modelURL)
        keywords = try container.decode([String].self, forKey: .keywords)
        emotions = try container.decode([String].self, forKey: .emotions)
        symbols = try container.decode([String].self, forKey: .symbols)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(statusUpdatedAt, forKey: .statusUpdatedAt)
        try container.encodeIfPresent(analysis, forKey: .analysis)
        try container.encodeIfPresent(modelURL, forKey: .modelURL)
        try container.encode(keywords, forKey: .keywords)
        try container.encode(emotions, forKey: .emotions)
        try container.encode(symbols, forKey: .symbols)
    }
}

enum DreamStatus: String, Codable {
    case draft = "Draft"
    case analyzing = "Analyzing"
    case analyzed = "Analyzed"  // 分析完成，但未生成模型
    case generating = "Generating"
    case completed = "Completed"
    case failed = "Failed"
}

struct DreamAnalysis: Codable {
    let keywords: [String]
    let emotions: [String]
    let symbols: [String]
    let visualDescription: String
    let interpretation: String
    
    enum CodingKeys: String, CodingKey {
        case keywords
        case emotions
        case symbols
        case visualDescription = "visual_description"
        case interpretation
    }
}
