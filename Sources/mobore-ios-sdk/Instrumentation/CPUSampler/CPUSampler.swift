import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public class CPUSampler {
    let meter: any Meter
    public init() {
        meter = OpenTelemetry.instance.meterProvider.meterBuilder(name: "CPU Sampler").build()

        
        _ = meter.gaugeBuilder(name: "system.cpu.usage").buildWithCallback() { gauge in
            if let usage = CPUSampler.cpuFootprint() {
                gauge.record(value: Double(usage), attributes: ["state": AttributeValue.string("app")])
            }
        }
    }

    private static func cpuFootprint() -> Double? {
        var kr: kern_return_t
        var task_info_count: mach_msg_type_number_t

        task_info_count = mach_msg_type_number_t(TASK_INFO_MAX)
        var tinfo = [integer_t](repeating: 0, count: Int(task_info_count))
        kr = task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), &tinfo, &task_info_count)
        if kr != KERN_SUCCESS {
            return nil
        }
        var thread_list: thread_act_array_t?
        var thread_count: mach_msg_type_number_t = 0
        defer {
            if let thread_list = thread_list {
                let address = vm_address_t(UInt(bitPattern: thread_list))
                let size = vm_size_t(thread_count) * vm_size_t(MemoryLayout<thread_t>.stride)
                vm_deallocate(mach_task_self_, address, size)
            }
        }

        kr = task_threads(mach_task_self_, &thread_list, &thread_count)

        if kr != KERN_SUCCESS {
            return nil
        }

        var totalCpuPercentage: Double = 0

        if let thread_list = thread_list {
            for j in 0 ..< Int(thread_count) {
                var thread_info_count = mach_msg_type_number_t(THREAD_INFO_MAX)
                var thinfo = [integer_t](repeating: 0, count: Int(thread_info_count))
                kr = thread_info(thread_list[j], thread_flavor_t(THREAD_BASIC_INFO),
                                 &thinfo, &thread_info_count)
                if kr != KERN_SUCCESS {
                    continue
                }

                let threadBasicInfo = CPUSampler.convertThreadInfoToThreadBasicInfo(thinfo)

                if threadBasicInfo.flags != TH_FLAGS_IDLE {
                    totalCpuPercentage += (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE)) * 100.0
                }
            } // for each thread
        }

        return totalCpuPercentage
    }

    fileprivate static func convertThreadInfoToThreadBasicInfo(_ threadInfo: [integer_t]) -> thread_basic_info {
        var result = thread_basic_info()

        result.user_time = time_value_t(seconds: threadInfo[0], microseconds: threadInfo[1])
        result.system_time = time_value_t(seconds: threadInfo[2], microseconds: threadInfo[3])
        result.cpu_usage = threadInfo[4]
        result.policy = threadInfo[5]
        result.run_state = threadInfo[6]
        result.flags = threadInfo[7]
        result.suspend_count = threadInfo[8]
        result.sleep_time = threadInfo[9]

        return result
    }
}
