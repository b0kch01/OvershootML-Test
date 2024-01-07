//
//  CGRectConvert.swift
//  OvershootML Test
//
//  Created by Nathan Choi on 1/5/24.
//

import UIKit

extension CGRect {
    init(centerProbRect c: CGRect, w: Double, h: Double) {
        self.init(
            x: w*(c.minX - c.width/2),
            y: h*(c.minY - c.height/2),
            width: w*c.width,
            height: h*c.height
        )
    }
}
