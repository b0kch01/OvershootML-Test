//
//  ContentView.swift
//  OvershootML Test
//
//  Created by Nathan Choi on 12/17/23.
//

import SwiftUI
import CoreML
import PhotosUI

struct BoundingBox {
    let x: Double
    let y: Double
    let w: Double
    let h: Double

    let openface: Double
}

struct ContentView: View {

    let faceModel: FaceFinderMed = try! FaceFinderMed()
    let blinkModel: BlinkClassifier = try! BlinkClassifier()

    @State var faces: [BoundingBox] = []

    @State var image: UIImage = UIImage(named: "blocked")!

    @State var imageItem: PhotosPickerItem?

    func predict() {

        let startTime = DispatchTime.now()
        print("Predicting:")

        do {
            guard let pixelBuffer = image.pixelBuffer(width: 960, height: 960) else {
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
                let x = Double(truncating: result.coordinates[r*colSize+0])
                let y = Double(truncating: result.coordinates[r*colSize+1])
                let w = Double(truncating: result.coordinates[r*colSize+2])
                let h = Double(truncating: result.coordinates[r*colSize+3])

                let croppedImage = image.cgImage!.cropping(
                    to: CGRect(
                        centerProbRect: CGRect(x: x, y: y, width: w, height: h),
                        w: image.size.width,
                        h: image.size.height
                    )
                )

                let probability = blinkProbability(
                    image: croppedImage,
                    orientation: image.imageOrientation
                )

                rects.append(BoundingBox(x: x, y: y, w: w, h: h, openface: probability ?? -1))
            }

            self.faces = rects
        } catch {
            print(error)
        }

        let endTime = DispatchTime.now()
        let elapsedTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds

        print("done in", Double(elapsedTime) / 1_000_000_000)
    }

    func blinkProbability(image: CGImage?, orientation: UIImage.Orientation) -> Double? {
        guard let image else {
            return nil
        }

        guard let pixelBuffer = image.pixelBuffer(
            width: 360,
            height: 360,
            orientation: CGImagePropertyOrientation(orientation)
        ) else {
            print("Blink Prob pixel buffer conversion failed")
            return nil
        }

        do {
            let output = try blinkModel.prediction(image: pixelBuffer)

            print(output.targetProbability["OpenFace"] ?? -1)
            return output.targetProbability["OpenFace"]
        } catch {
            print(error)
        }

        return nil
    }

    var body: some View {
        VStack {
            PhotosPicker("Select Image", selection: $imageItem, matching: .images)
                .onChange(of: imageItem) {
                    Task {
                        if let loaded = try? await imageItem?.loadTransferable(type: Data.self) {
                            image = UIImage(data: loaded) ?? UIImage()
                        }
                    }
                }

            Button("predict", action: {
                predict()
            })
            .padding(20)
            .background()

            GeometryReader { geo in
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)

                    ForEach(faces.indices, id:\.self) { i in
                        Spacer()
                            .border(
                                faces[i].openface == -1 ? .cyan :
                                    faces[i].openface > 0.4 ? .green : .red
                                , width: 1)
                            .frame(
                                width: faces[i].w * geo.size.width,
                                height: faces[i].h * geo.size.height
                            )
                            .overlay(
                                Text(String(format: "%.1f", faces[i].openface))
                                    .font(.caption2)
                                    .foregroundStyle(
                                        faces[i].openface == -1 ? .cyan :
                                            faces[i].openface > 0.4 ? .green : .red)
                                ,
                                alignment: .bottomLeading
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
