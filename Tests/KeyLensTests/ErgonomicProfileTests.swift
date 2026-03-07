import XCTest
@testable import KeyLensCore

final class ErgonomicProfileTests: XCTestCase {
    
    func testStandardProfile() {
        let profile = ErgonomicProfile.standard
        XCTAssertEqual(profile.name, "Standard")
        XCTAssertEqual(profile.fingerWeights.weight(for: .thumb), 0.8)
        XCTAssertNil(profile.splitConfig)
    }
    
    func testSplitErgoProfile() {
        let profile = ErgonomicProfile.splitErgo
        XCTAssertEqual(profile.name, "Split Ergonomic")
        XCTAssertEqual(profile.fingerWeights.weight(for: .thumb), 1.0)
        XCTAssertNotNil(profile.splitConfig)
    }
    
    func testLayoutRegistryAutoDetection() {
        let registry = LayoutRegistry()
        
        // Test standard fallback
        registry.applyProfile(forDeviceNames: ["Generic Keyboard", "Apple Internal Keyboard"])
        XCTAssertEqual(registry.activeProfile.name, ErgonomicProfile.standard.name)
        XCTAssertEqual(registry.activeProfile.fingerWeights.weight(for: .thumb), 0.8)
        XCTAssertEqual(registry.currentDeviceLabel, "Apple Internal Keyboard / Generic Keyboard")
        
        // Test split keyboard detection
        registry.applyProfile(forDeviceNames: ["ZSA Moonlander", "Apple Internal Keyboard"])
        XCTAssertEqual(registry.activeProfile.name, ErgonomicProfile.splitErgo.name)
        XCTAssertEqual(registry.activeProfile.fingerWeights.weight(for: .thumb), 1.0)
        
        // Test ergo keyword
        registry.applyProfile(forDeviceNames: ["ErgoDox EZ"])
        XCTAssertEqual(registry.activeProfile.name, ErgonomicProfile.splitErgo.name)
        
        // Test Pangaea keyboard
        registry.applyProfile(forDeviceNames: ["Pangaea Keyboard"])
        XCTAssertEqual(registry.activeProfile.name, ErgonomicProfile.splitErgo.name)
    }
    
    func testResolvedDeviceLabelNormalizesNames() {
        XCTAssertEqual(
            LayoutRegistry.resolvedDeviceLabel(for: ["ZSA Moonlander", "  Apple Internal Keyboard  ", "ZSA Moonlander"]),
            "Apple Internal Keyboard / ZSA Moonlander"
        )
        XCTAssertEqual(LayoutRegistry.resolvedDeviceLabel(for: []), "Unknown Keyboard")
        XCTAssertEqual(LayoutRegistry.resolvedDeviceLabel(for: ["   "]), "Unknown Keyboard")
    }
    
    func testWeightResolution() {
        let registry = LayoutRegistry()
        
        // Standard profile: Space (thumb) -> 0.8
        registry.activeProfile = .standard
        XCTAssertEqual(registry.loadWeight(for: "Space"), 0.8)
        
        // Split profile: Space (thumb) -> 1.0
        registry.activeProfile = .splitErgo
        XCTAssertEqual(registry.loadWeight(for: "Space"), 1.0)
    }
}
