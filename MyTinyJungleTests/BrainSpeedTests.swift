import Testing
import UIKit
import ImageIO
@testable import MyTinyJungle

/// Upload prep, result cache, stream parsing and display-size decoding.
struct BrainSpeedTests {
    private func photo(_ w: Int, _ h: Int) -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
            .image { c in UIColor.systemGreen.setFill(); c.fill(CGRect(x: 0, y: 0, width: w, height: h)); UIColor.brown.setFill(); c.fill(CGRect(x: 0, y: h / 2, width: w, height: h / 2)) }
            .pngData()!
    }
    private func pixels(_ d: Data) -> (Int, Int) {
        let p = CGImageSourceCopyPropertiesAtIndex(CGImageSourceCreateWithData(d as CFData, nil)!, 0, nil) as! [CFString: Any]
        return (p[kCGImagePropertyPixelWidth] as! Int, p[kCGImagePropertyPixelHeight] as! Int)
    }

    @Test func uploadIs768JpegAndMadeOnce() {
        let raw = photo(3000, 2000)
        let a = BrainPhoto.make(raw), b = BrainPhoto.make(raw)
        #expect(a.jpeg.starts(with: [0xFF, 0xD8]))
        let (w, h) = pixels(a.jpeg)
        #expect(max(w, h) == 768 && min(w, h) == 512)
        #expect(a.sha == b.sha && a.sha.count == 64)
        #expect(a.jpeg == b.jpeg)
    }

    @Test func smallPhotosAreNotUpscaled() {
        let (w, h) = pixels(BrainPhoto.make(photo(400, 300)).jpeg)
        #expect(w == 400 && h == 300)
    }

    @Test func cacheRoundTrip() {
        struct R: Codable, Equatable { var x: Int }
        let key = BrainCache.key("test", UUID().uuidString)
        #expect((BrainCache.get(key) as R?) == nil)
        BrainCache.put(key, try! JSONEncoder().encode(R(x: 7)))
        #expect((BrainCache.get(key) as R?) == R(x: 7))
        BrainCache.clear()
        #expect((BrainCache.get(key) as R?) == nil)
    }

    @Test func sseFields() {
        #expect(JungleAPI.sseField("data: {\"a\":1}") == ("data", "{\"a\":1}"))
        #expect(JungleAPI.sseField("event:answer") == ("event", "answer"))
        #expect(JungleAPI.sseField("data:  two") == ("data", " two"))
    }

    @Test func streamFoldsIntoOneReply() {
        let e = { (n: String, s: String) in JungleAPI.Event(name: n, data: Data(s.utf8)) }
        let r = Brain.reply(from: [
            e("answer", #"{"kind":"topic","title":"Light","text":"Bright, indirect."}"#),
            e("message", #"{"answers":[{"kind":"pest","title":"Mites","text":"Wipe leaves."}]}"#),
            e("weather", #"{"tMin":4,"tMax":12}"#),
            e("done", "{}"),
        ])
        #expect(r.answers?.map(\.title) == ["Light", "Mites"])
        #expect(r.weather?.tMin == 4)
    }

    @Test func thumbsDecodeAtDisplaySize() {
        let img = Thumbs.image(photo(4000, 3000), side: 100)
        #expect(img != nil)
        // Shorter edge fills 100 pt at 3x; never the 4000 px original.
        #expect(Int(img!.size.height) == 300 && Int(img!.size.width) == 400)
    }
}
