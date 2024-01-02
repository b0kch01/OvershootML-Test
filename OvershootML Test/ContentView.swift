//
//  ContentView.swift
//  OvershootML Test
//
//  Created by Nathan Choi on 12/17/23.
//

import SwiftUI
import CoreML

struct BoundingBox {
    let x: Double
    let y: Double
    let w: Double
    let h: Double
}

struct ContentView: View {

    @State var faces: [BoundingBox] = []

    let faceModel: FaceFinderMed = try! FaceFinderMed()
    let blinkModel: BlinkClassifier = try! BlinkClassifier()
//    let deeplab: DeepLabV3_model = try! DeepLabV3_model()
    let IMAGE = "blocked"


    func predict() {

        let startTime = DispatchTime.now()
        print("Predicting:")

        do {
            guard let uiImage = UIImage(named: IMAGE) else {
                print("Image load failed")
                return
            }

            guard let pixelBuffer = uiImage.pixelBuffer(width: 960, height: 960) else {
                print("Pixelbuffer failed")
                return
            }

            let result = try self.faceModel.prediction(
                image: pixelBuffer,
                iouThreshold: 0.5,
                confidenceThreshold: 0.3
            )

            let rows = Int(truncating: result.coordinates.shape[0])
            let colSize = 4

            var rects = [BoundingBox]()

            for r in 0..<rows {
                let x = result.coordinates[r*colSize+0]
                let y = result.coordinates[r*colSize+1]
                let w = result.coordinates[r*colSize+2]
                let h = result.coordinates[r*colSize+3]

                rects.append(BoundingBox(
                    x: Double(truncating: x),
                    y: Double(truncating: y),
                    w: Double(truncating: w),
                    h: Double(truncating: h)
                ))
            }

            self.faces = rects
        } catch {
            print(error)
        }

        let endTime = DispatchTime.now()
        let elapsedTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds

        print("done in", Double(elapsedTime) / 1_000_000_000)
    }

    func blinked() {
        guard let uiImage = UIImage(named: IMAGE) else {
            print("Image load failed")
            return
        }


        for box in self.faces {
            guard let ciImage = CIImage(image: uiImage) else {
                print("Ci image conversion failed")
                return
            }

            let croppedImage = ciImage.cropped(
                to: CGRect(x: box.x, y: box.y, width: box.w, height: box.h)
            )

            guard let pixelBuffer = UIImage(ciImage: croppedImage).pixelBuffer(width: 360, height: 360) else {
                print("Pixel buffer conversion failed")
                return
            }

            do {
                let output = try blinkModel.prediction(
                    image: pixelBuffer
                )

                print(output.featureNames)
                print(output.target)
                print(output.targetProbability)
            } catch {
                print(error)
            }
        }
    }

    var body: some View {
        VStack {
            Button("predict", action: {
                predict()
                blinked()
            })
            .padding(20)
            .background()

            GeometryReader { geo in
                ZStack {
                    Image(IMAGE)
                        .resizable()
                        .aspectRatio(contentMode: .fit)

                    ForEach(faces.indices, id:\.self) { i in
                        Spacer()
                            .border(.red, width: 1)
                            .frame(
                                width: faces[i].w * geo.size.width,
                                height: faces[i].h * geo.size.height
                            )
                            .position(
                                x: faces[i].x * geo.size.width,
                                y: faces[i].y * geo.size.height
                            )

                    }
                }
            }
            .scaledToFit()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
