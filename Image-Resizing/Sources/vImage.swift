import UIKit
import Accelerate.vImage

enum vImage {
    static func resizedImage(at url: URL, for size: CGSize) -> UIImage? {
        precondition(size != .zero)

        guard let imageSource = CGImageSourceCreateWithURL(url as NSURL, nil),
            let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
            let imageWidth = properties[kCGImagePropertyPixelWidth] as? vImagePixelCount,
            let imageHeight = properties[kCGImagePropertyPixelHeight] as? vImagePixelCount
        else {
           return nil
        }
        
        var format = vImage_CGImageFormat(bitsPerComponent: 8,
                                          bitsPerPixel: 32,
                                          colorSpace: nil,
                                          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
                                          version: 0,
                                          decode: nil,
                                          renderingIntent: .defaultIntent)
        
        var error: vImage_Error
        
        var sourceBuffer = vImage_Buffer()
        defer { sourceBuffer.data.deallocate() }
        error = vImageBuffer_InitWithCGImage(&sourceBuffer,
                                             &format,
                                             nil,
                                             image,
                                             vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }
        
        var destinationBuffer = vImage_Buffer()
        error = vImageBuffer_Init(&destinationBuffer,
                                  vImagePixelCount(size.height),
                                  vImagePixelCount(size.width),
                                  format.bitsPerPixel,
                                  vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }

        error = vImageScale_ARGB8888(&sourceBuffer,
                                     &destinationBuffer,
                                     nil,
                                     vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }

        guard let resizedImage =
            vImageCreateCGImageFromBuffer(&destinationBuffer,
                                          &format,
                                          nil,
                                          nil,
                                          vImage_Flags(kvImageNoAllocate),
                                          &error)?.takeRetainedValue(),
            error == kvImageNoError
        else {
            return nil
        }
        
        return UIImage(cgImage: resizedImage)
    }
}
