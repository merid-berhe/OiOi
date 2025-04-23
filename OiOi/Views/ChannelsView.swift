import SwiftUI

struct ChannelsView: View {
    @State private var channels = Channel.defaultChannels
    @State private var showNSFW = false
    
    var filteredChannels: [Channel] {
        channels.filter { channel in
            showNSFW ? true : !channel.isNSFW
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Toggle("Show NSFW Content", isOn: $showNSFW)
                    .tint(.red)
                
                ForEach(filteredChannels) { channel in
                    NavigationLink(destination: ChannelDetailView(channel: channel)) {
                        HStack(spacing: 12) {
                            Image(systemName: channel.iconName)
                                .font(.title2)
                                .foregroundColor(channel.isNSFW ? .red : .blue)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(channel.name)
                                    .font(.headline)
                                
                                Text(channel.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Channels")
        }
    }
}

struct ChannelDetailView: View {
    let channel: Channel
    @State private var posts: [AudioPost] = []
    @State private var isSubscribed = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Channel Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: channel.iconName)
                            .font(.largeTitle)
                            .foregroundColor(channel.isNSFW ? .red : .blue)
                        
                        VStack(alignment: .leading) {
                            Text(channel.name)
                                .font(.title)
                                .bold()
                            
                            Text("\(channel.subscribers.count) subscribers")
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            isSubscribed.toggle()
                        }) {
                            Text(isSubscribed ? "Subscribed" : "Subscribe")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isSubscribed ? Color.gray : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                        }
                    }
                    
                    Text(channel.description)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Posts
                LazyVStack(spacing: 12) {
                    ForEach(0..<5) { _ in
                        AudioPostCard(post: .preview,
                                      onLike: { /* Placeholder action */ },
                                      onPlay: { /* Placeholder action */ })
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ChannelsView()
} 