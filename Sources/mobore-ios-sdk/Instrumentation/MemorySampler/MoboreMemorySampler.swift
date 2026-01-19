import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public class MoboreMemorySampler {
    let meter: any Meter

    public init() {
        meter = OpenTelemetry.instance.meterProvider.meterBuilder(name: "Memory Sampler").build()
    
        _ = meter.gaugeBuilder(name: "system.memory.usage").buildWithCallback() { gauge in
            if let memoryUsage = MoboreMemorySampler.memoryFootprint() {
                gauge.observe(value: Double(memoryUsage), attributes: ["state": AttributeValue.string("app")])
            }
        }
    }

    private static func memoryFootprint() -> mach_vm_size_t? {
        // The `TASK_VM_INFO_COUNT` and `TASK_VM_INFO_REV1_COUNT` macros are too
        // complex for the Swift C importer, so we have to define them ourselves.
        let TASK_VM_INFO_COUNT = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let TASK_VM_INFO_REV1_COUNT = mach_msg_type_number_t(MemoryLayout.offset(of: \task_vm_info_data_t.min_address)! / MemoryLayout<integer_t>.size)
        var info = task_vm_info_data_t()
        var count = TASK_VM_INFO_COUNT
        let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }
        guard
            kr == KERN_SUCCESS,
            count >= TASK_VM_INFO_REV1_COUNT
        else { return nil }
        return info.phys_footprint
    }
}
