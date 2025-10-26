//
//  PersonBadge.swift
//  bank-management
//
//  Created by KOCHI on 2025/10/13.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct PersonBadge: View {
    var name: String
#if os(macOS)
    var avatar: NSImage?
#else
    var avatar: UIImage?
#endif
    
    var body: some View {
        HStack(spacing: 12) {
            avatarView
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.title3.bold()).lineLimit(1)
        }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial).shadow(radius: 1))
    }
    
#if os(macOS)
    @ViewBuilder private var avatarView: some View {
        if let avatar {
            Image(nsImage: avatar).resizable().scaledToFill()
                .frame(width: 48, height: 48).clipShape(Circle())
                .overlay(Circle().stroke(.separator, lineWidth: 1))
        } else {
            Image(systemName: "person.crop.circle.fill.badge.plus")
                .font(.system(size: 48)).foregroundStyle(.secondary)
        }
    }
#else
    @ViewBuilder private var avatarView: some View {
        if let avatar {
            Image(uiImage: avatar).resizable().scaledToFill()
                .frame(width: 48, height: 48).clipShape(Circle())
                .overlay(Circle().stroke(.separator, lineWidth: 1))
        } else {
            Image(systemName: "person.crop.circle.fill.badge.plus")
                .font(.system(size: 48)).foregroundStyle(.secondary)
        }
    }
#endif
}
