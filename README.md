# ImageResizing
图片缩放技术
iOS图像缩放技术对比
一、简介：
入职从事iOS开发以来，发现app开发过程中不可避免需要和图片打交道，目前iOS开发中最常见的有以下5种技术：Core Graphics、vImage 、 Image I/O、 Core Image 和 UIKit。目前在海外iOS开发代码中可以发现大部分使用的技术是UIKit：UIGraphicsBeginImageContextWithOptions，常见场景比如个人页展示、直播业务涉及到的相关图片展示等，另外在生产模块中还使用了Core Graphics：CGBitmapContextCreate、CGContextDrawImage等。而腾讯微信最早是使用UIKit，后来改使用ImageIO。另外苹果官方Performance Best Practices section of the Core Image Programming Guide 部分中特别推荐使用Core Graphics或Image I / O功能预先裁剪或缩小图像。那么究竟这五种技术优劣如何，可以通过以下实验进行比较分析。
二、技术简介：
1、UIKit：
UIKit 是Apple官方提供的一個框架，用来构建常见的UI功能，它提供了很多绘制图像，调整图像大小的API，例如常用的UIGraphicsBeginImageContextWithOptions & UIImage -drawInRect:，给定一个UIImage，可以使用临时图形上下文来渲染缩放版本。 iOS 10 中引入UIGraphicsImageRenderer代替UIGraphicsBeginImageContext。UIGraphicsImageRenderer官方文档的解释：一个支持创建核心图像的渲染器。其可以提升加载大图的速度。使用代码如下：import UIKit
static func resizedImage(at url: URL, for size: CGSize) -> UIImage? 		{
        guard let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { (context) in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
}
其可以在不更改原始图像纵横比的情况下缩放图片以使用框架大小。
2、Core Graphics：
CoreGraphics / Quartz 2D提供了一套较低级别的API，允许进行更高级的配置。 给定一个CGImage，使用临时位图上下文来渲染缩放后的图像。使用CoreGraphics图像的质量与UIKit图像相同，很难肉眼分辨差别。使用代码如下：
import UIKit
import CoreGraphics

static func resizedImage(at url: URL, for size: CGSize) -> UIImage? 		{
        precondition(size != .zero)

        guard let imageSource = CGImageSourceCreateWithURL(url as NSURL, nil),
            let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            return nil
        }
        
        let context = CGContext(data: nil,
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: image.bitsPerComponent,
                                bytesPerRow: image.bytesPerRow,
                                space: image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: image.bitmapInfo.rawValue)
        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(origin: .zero, size: size))
        
        guard let scaledImage = context?.makeImage() else { return nil 		}
        
        return UIImage(cgImage: scaledImage)
}

3、 Image I/O：
	Image I/O 独立于 Core Graphics，是一个强大的用于处理图像的框架，可以在多种不同格式之间进行读写、访问照片元数据以及执行常见的图像处理操作。该框架提供平台上最快的图像编码器和解码器，具有先进的缓存机制，甚至可以逐步加载图像。
Image I/O 提供了一个简洁的 API，CGImageSourceCreateThumbnailAtIndex，使用代码如下：
import UIKit
import ImageIO
import MobileCoreServices

static func resizedImage(at url: URL, for size: CGSize) -> UIImage? 		{
        precondition(size != .zero)

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        
        guard let imageSource = CGImageSourceCreateWithURL(url as NSURL, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
        else {
            return nil
        }
        
        return UIImage(cgImage: image)
    }
    
    static func resizedImageWithHintingAndSubsampling(at url: URL, for size: CGSize) -> UIImage? {
        precondition(size != .zero)
        
        guard let imageSource = CGImageSourceCreateWithURL(url as NSURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
            let imageWidth = properties[kCGImagePropertyPixelWidth] as? CGFloat,
            let imageHeight = properties[kCGImagePropertyPixelHeight] as? CGFloat
        else {
            return nil
        }
        
        var options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, url.pathExtension as CFString, kUTTypeImage)?.takeRetainedValue() {
            options[kCGImageSourceTypeIdentifierHint] = uti
            
            if uti == kUTTypeJPEG || uti == kUTTypeTIFF || uti == kUTTypePNG ||
                String(uti).hasPrefix("public.heif")
            {
                switch min(imageWidth / size.width, imageHeight / size.height) {
                case ...2.0:
                    options[kCGImageSourceSubsampleFactor] = 2.0
                case 2.0...4.0:
                    options[kCGImageSourceSubsampleFactor] = 4.0
                case 4.0...:
                    options[kCGImageSourceSubsampleFactor] = 8.0
                default:
                    break
                }
            }
           
        }
        
        guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }
        
        return UIImage(cgImage: image)
}
4、 Core Image：
	 Core Image是一个很强大的框架， 它基于OpenGL顶层创建，底层则用着色器来处理图像。它可以让你简单地应用各种滤镜来处理图像，比如修改鲜艳程度, 色泽, 或者曝光，对图像进行滤镜操作，比如模糊、颜色改变、锐化、人脸识别等。 它利用GPU（或者CPU）来非常快速、甚至实时地处理图像数据和视频的帧。并且隐藏了底层图形处理的所有细节，通过提供的API就能简单的使用了，无须关心OpenGL或者OpenGL ES是如何充分利用GPU的能力的，也不需要你知道GCD在其中发挥了怎样的作用，Core Image处理了全部的细节。还可以将CIImage对象与其他核心图像类(如CIFilter、CIContext、CIVector和cicoll)结合使用，以便在处理图像时利用内置的核心图像滤镜。图像缩放时使用代码如下：
import UIKit
import CoreImage

static let sharedContext = CIContext(options: [.useSoftwareRenderer : false])
    
    static func resizedImage(at url: URL, for size: CGSize) -> UIImage? 		{
        precondition(size != .zero)
        
        guard let imageSource = CGImageSourceCreateWithURL(url as NSURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
            let imageWidth = properties[kCGImagePropertyPixelWidth] as? CGFloat,
            let imageHeight = properties[kCGImagePropertyPixelHeight] as? CGFloat
        else {
            return nil
        }
        
        let scale = max(size.width, size.height) /
                    max(imageWidth, imageHeight)
        guard scale >= 0, !scale.isInfinite, !scale.isNaN else { return nil }

        let aspectRatio = imageWidth / imageHeight
        guard aspectRatio >= 0, !aspectRatio.isInfinite, !aspectRatio.isNaN else { return nil }

        return resizedImage(at: url, scale: scale, aspectRatio: aspectRatio)
    }
    
    static func resizedImage(at url: URL, scale: CGFloat, aspectRatio: CGFloat) -> UIImage? {
        precondition(aspectRatio > 0.0)
        precondition(scale > 0.0)
        
        guard let image = CIImage(contentsOf: url) else {
            return nil
        }
        
        let filter = CIFilter(name: "CILanczosScaleTransform")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(scale, forKey: kCIInputScaleKey)
        filter?.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)
        
        guard let outputCIImage = filter?.outputImage,
            let outputCGImage = sharedContext.createCGImage(outputCIImage, from: outputCIImage.extent)
        else {
            return nil
        }
        
        return UIImage(cgImage: outputCGImage)
 }
5、vImage ：
vImage 是一个高性能的图像处理框架。它包括用于图像处理的函数——卷积、几何变换、直方图操作、形态变换和 alpha 合成——以及用于格式转换和其他操作的实用函数。
vImage 通过使用 CPU 的矢量处理器优化图像处理。如果矢量处理器不可用，vImage 将使用下一个最佳可用选项。该框架使您无需编写矢量化代码即可获得矢量处理器的优势。其可以产生最佳效果，并且图像清晰平衡。 没有CG那么模糊，又不像CI那样明亮的不自然。
其使用方法可以参考官方文档https://developer.apple.com/documentation/accelerate/vimage。
其图像缩放应用代码如下：
import UIKit
import Accelerate.vImage

 static func resizedImage(at url: URL, for size: CGSize) -> UIImage? 
 {
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

三、实验分析：
	为了验证上述5种技术的优劣性，在网上找到一张像素为9365 × 9399，大小为18MB的图像，给予iOS14.5，iPhone8 分别使用5种技术将其尺寸缩放到100*100的图片展示在手机上，如图所示：
 
代码如下：
import UIKit

class ViewController: UIViewController {
    @IBOutlet var imageView: UIImageView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard let url = Bundle.main.url(forResource: "longbeach",
                                        withExtension: "jpg")
        else {
            fatalError("Missing image resource")
        }
        
        let scaleFactor = UIScreen.main.scale
        let scale = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        let size = self.imageView.bounds.size.applying(scale)
        
        DispatchQueue.global(qos: .userInitiated).async {
            let start = CACurrentMediaTime()
            
//            let image = UIImage(contentsOfFile: url.path)
//            let image = CoreGraphics.resizedImage(at: url, for: size)
//            let image = CoreImage.resizedImage(at: url, for: size)
//            let image = ImageIO.resizedImage(at: url, for: size)
            let image = ImageIO.resizedImageWithHintingAndSubsampling(at: url, for: size)
//            let image = UIKit.resizedImage(at: url, for: size)
//            let image = vImage.resizedImage(at: url, for: size)
            
            DispatchQueue.main.sync {
                let duration = 1.0
                UIView.transition(with: self.imageView, duration: duration, options: [.curveEaseOut, .transitionCrossDissolve], animations: {
                    self.imageView.image = image
                }, completion: { _ in
                    let end = CACurrentMediaTime()
                    print(end - start - duration)
                })
            }
        }
    }
}



技术方法	加载时间
Core Graphics	0.694391960001667
vImage	1.1731584489898523
Image I/O	0.7204799330065725
Core Image	3.0658174099953612
UIKit	0.8151104930002475可以看到Core Image表现最差，UIKit、Core Graphics 和 Image I/O表现最好。而我们快手使用最多的也就是前两种框架，而微信之所以早年使用UIKit，后来改使用ImageIO，是因为UIKit处理大分辨率图片时，往往容易出现OOM，原因是-[UIImage drawInRect:]在绘制时，先解码图片，再生成原始分辨率大小的bitmap，这是很耗内存的。解决方法是使用更低层的ImageIO接口，避免中间bitmap产生。因此其实个人觉得我们也应该更多的尝试使用Image I/O，另外技术不断更新换代，不断学习尝试新的方法才是进步的源泉。
github:https://github.com/wanghaoyan/ImageResizing.git



