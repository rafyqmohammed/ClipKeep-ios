//
//  ClipItemView.swift
//  ClipKeep
//
//  Created by tamtam-8 on 6/4/2026.
//

import SwiftUI

struct ClipItemView: View {
    let item: ClipItem
    
    var body: some View {
        HStack(spacing: 12) {
            if item.type == .image, let uiImage = UIImage(data: item.contentData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            } else {
                Image(systemName: item.type == .url ? "link" : "doc.text")
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading) {
                Text(item.type == .image ? "Image enregistrée" : item.textValue)
                    .lineLimit(2)
                Text(item.createdAt, style: .time)
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    
}
