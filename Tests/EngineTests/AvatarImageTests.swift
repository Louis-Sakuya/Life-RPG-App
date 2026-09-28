import UIKit
import XCTest
@testable import LifeRPG

final class AvatarImageTests: XCTestCase {

    func testPreparedImageIsSquareAndCapped() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 400), format: {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            return format
        }())
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 800, height: 400))
        }

        guard let data = AvatarImage.prepared(from: image), let result = UIImage(data: data) else {
            return XCTFail("头像压缩后应该能还原成图片")
        }

        XCTAssertEqual(result.size.width, result.size.height, accuracy: 1)
        XCTAssertLessThanOrEqual(result.size.width, AvatarImage.maxDimension + 1)
    }
}
