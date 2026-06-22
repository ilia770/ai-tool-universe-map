import SwiftUI

struct UserAvatarImage: View {
    let size: CGFloat
    let tint: Color

    var body: some View {
        Image("UserAvatar")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
            .liquidGlass(in: Circle(), tint: tint, strokeStrength: 0.12)
    }
}

#Preview {
    UserAvatarImage(size: 72, tint: BrandColor.cyan)
        .padding()
        .background(BrandColor.void)
}
