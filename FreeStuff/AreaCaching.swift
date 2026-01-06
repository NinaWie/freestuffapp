//
//  AreaCaching.swift
//  FreeStuff
//
//  Created by Nina Wiedemann on 05.01.26.
//  Copyright © 2026 Nina Wiedemann. All rights reserved.
//
import SwiftUI

import MapKit

struct CachedRegion {
    let neLat: Double
    let neLng: Double
    let swLat: Double
    let swLng: Double

    init(center: CLLocationCoordinate2D, span: MKCoordinateSpan) {
        let halfLat = span.latitudeDelta / 2
        let halfLng = span.longitudeDelta / 2

        self.neLat = center.latitude + halfLat
        self.neLng = center.longitude + halfLng
        self.swLat = center.latitude - halfLat
        self.swLng = center.longitude - halfLng
    }
}

struct FilterKey: Hashable {
    let showGoods: Bool
    let showFood: Bool
    let goodsSubcategory: String
    let foodSubcategory: String
    let timePostedMax: Float
    let showPermanent: Bool
}

struct PinCacheEntry {
    let pins: [Artwork]
    let region: CachedRegion
    let filters: FilterKey
    let isTruncated: Bool
    let timestamp: Date
}


extension CachedRegion {

    func inflated(by factor: Double = 0.25) -> CachedRegion {
        let latDelta = neLat - swLat
        let lngDelta = neLng - swLng

        return CachedRegion(
            neLat: neLat + latDelta * factor,
            neLng: neLng + lngDelta * factor,
            swLat: swLat - latDelta * factor,
            swLng: swLng - lngDelta * factor
        )
    }

    // Private initializer for internal use
    private init(neLat: Double, neLng: Double, swLat: Double, swLng: Double) {
        self.neLat = neLat
        self.neLng = neLng
        self.swLat = swLat
        self.swLng = swLng
    }
}



final class PinCache {

    static let shared = PinCache()

    private var entries: [PinCacheEntry] = []

    // Tuning knobs
    private let ttl: TimeInterval = 60        // seconds
    private let maxEntries = 30

    private init() {}

    func findCoveringEntry(
        for region: CachedRegion,
        filters: FilterKey
    ) -> PinCacheEntry? {

        let now = Date()

        // Iterate newest → oldest (better hit rate)
        for entry in entries.reversed() {

            // TTL check
            if now.timeIntervalSince(entry.timestamp) > ttl {
                continue
            }

            // Filters must match exactly
            if entry.filters != filters {
                continue
            }

            // Never reuse truncated data for containment
            if entry.isTruncated {
                continue
            }

            // Spatial containment
            if contains(outer: entry.region, inner: region) {
                return entry
            }
        }
        return nil
    }

    func store(
        pins: [Artwork],
        region: CachedRegion,
        filters: FilterKey,
        isTruncated: Bool
    ) {

        let entry = PinCacheEntry(
            pins: pins,
            region: region,
            filters: filters,
            isTruncated: isTruncated,
            timestamp: Date()
        )

        entries.append(entry)

        // Evict oldest entries if needed
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }


    private func contains(
        outer: CachedRegion,
        inner: CachedRegion
    ) -> Bool {
        outer.neLat >= inner.neLat &&
        outer.neLng >= inner.neLng &&
        outer.swLat <= inner.swLat &&
        outer.swLng <= inner.swLng
    }
}
