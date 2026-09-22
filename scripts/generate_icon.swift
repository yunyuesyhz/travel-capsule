import AppKit
import ImageIO
let root = CommandLine.arguments[1]
func icon(_ size: Int) -> Data {
 let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep)
 let s=CGFloat(size);let context=NSGraphicsContext.current!.cgContext
 context.scaleBy(x:s/1024,y:s/1024)
 let background=NSGradient(colors:[
   NSColor(calibratedRed:0.42,green:0.80,blue:0.89,alpha:1),
   NSColor(calibratedRed:0.77,green:0.93,blue:0.96,alpha:1),
 ])!
 background.draw(in:NSRect(x:0,y:0,width:1024,height:1024),angle:-55)

 NSColor(calibratedRed:1,green:0.71,blue:0.36,alpha:1).setFill()
 NSBezierPath(ovalIn:NSRect(x:650,y:650,width:190,height:190)).fill()

 let coast=NSBezierPath()
 coast.move(to:NSPoint(x:0,y:0));coast.line(to:NSPoint(x:0,y:365))
 coast.curve(to:NSPoint(x:500,y:350),controlPoint1:NSPoint(x:190,y:500),controlPoint2:NSPoint(x:330,y:260))
 coast.curve(to:NSPoint(x:1024,y:440),controlPoint1:NSPoint(x:700,y:470),controlPoint2:NSPoint(x:830,y:345))
 coast.line(to:NSPoint(x:1024,y:0));coast.close()
 NSColor(calibratedRed:0.18,green:0.61,blue:0.58,alpha:1).setFill();coast.fill()

 let route=NSBezierPath();route.lineCapStyle = .round;route.lineJoinStyle = .round
 route.move(to:NSPoint(x:235,y:245))
 route.curve(to:NSPoint(x:500,y:520),controlPoint1:NSPoint(x:290,y:430),controlPoint2:NSPoint(x:415,y:590))
 route.curve(to:NSPoint(x:760,y:710),controlPoint1:NSPoint(x:625,y:420),controlPoint2:NSPoint(x:680,y:600))
 route.lineWidth=64
 NSColor.white.setStroke();route.stroke()
 NSColor.white.setFill();NSBezierPath(ovalIn:NSRect(x:201,y:211,width:68,height:68)).fill()
 let arrow=NSBezierPath();arrow.move(to:NSPoint(x:785,y:770));arrow.line(to:NSPoint(x:825,y:655));arrow.line(to:NSPoint(x:760,y:692));arrow.line(to:NSPoint(x:695,y:655));arrow.close();arrow.fill()
 NSGraphicsContext.restoreGraphicsState()
 let opaque=CGContext(data:nil,width:size,height:size,bitsPerComponent:8,bytesPerRow:size*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
 opaque.draw(rep.cgImage!,in:CGRect(x:0,y:0,width:size,height:size))
 let data=NSMutableData();let destination=CGImageDestinationCreateWithData(data,"public.png" as CFString,1,nil)!
 CGImageDestinationAddImage(destination,opaque.makeImage()!,nil);CGImageDestinationFinalize(destination);return data as Data
}
for (folder,size) in [("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)] {try icon(size).write(to:URL(fileURLWithPath:root+"/android/app/src/main/res/mipmap-\(folder)/ic_launcher.png"))}
try icon(512).write(to:URL(fileURLWithPath:root+"/docs/screenshots/app-icon.png"))
