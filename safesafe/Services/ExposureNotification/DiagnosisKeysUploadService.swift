//
//  DiagnosisKeysUploadService.swift
//  safesafe
//

import Moya
import PromiseKit
import ExposureNotification

protocol DiagnosisKeysUploadServiceProtocol {
    
    func upload(usingAuthCode authCode: String) -> Promise<Void>
    
}

enum UploadError: Error {
    case noInternet(shouldRetry: Bool)
    case general(shouldRetry: Bool, code: Int)
    case unknown(Error)
}

@available(iOS 13.5, *)
final class DiagnosisKeysUploadService: DiagnosisKeysUploadServiceProtocol {
        
    // MARK: - Properties
    
    private let exposureManager: ExposureServiceProtocol
    private let deviceCheckService: DeviceCheckServiceProtocol
    private let renewableRequest: RenewableRequest<ExposureKeysTarget>
    
    // MARK: - Life Cycle
    
    init(
        with exposureManager: ExposureServiceProtocol,
        deviceCheckService: DeviceCheckServiceProtocol,
        exposureKeysProvider: MoyaProvider<ExposureKeysTarget>
    ) {
        self.exposureManager = exposureManager
        self.deviceCheckService = deviceCheckService
        self.renewableRequest = .init(provider: exposureKeysProvider, alertManager: NetworkingAlertManager())
    }
    
    // MARK: - Exposure Keys
    
    func upload(usingAuthCode authCode: String) -> Promise<Void> {
        var diagnosisKeys: [ENTemporaryExposureKey] = []
        var uploadPayload: String = ""
        return getDiagnosisKeys()
            .then { keys -> Promise<String> in
                diagnosisKeys = keys
                return self.getPayload(keys: diagnosisKeys)
        }
        .then { payload -> Promise<String> in
            uploadPayload = payload
            return self.getToken(usingAuthCode: authCode)
        }
        .then { token -> Promise<Moya.Response> in
            let data = TemporaryExposureKeys(
                temporaryExposureKeys: diagnosisKeys.map({ TemporaryExposureKey($0) }),
                verificationPayload: token,
                deviceVerificationPayload: uploadPayload
            )
            let keysData = TemporaryExposureKeysData(data: data)
            
            return self.renewableRequest.make(target: .post(keysData))
        }
        .asVoid()
    }
    
    private func getDiagnosisKeys(filtered: Bool = true) -> Promise<[ENTemporaryExposureKey]> {
        if filtered {
            return exposureManager
                .getDiagnosisKeys()
                .filterValues(discardOldKeys)
        } else {
            return exposureManager
                .getDiagnosisKeys()
        }
    }
    
    private func getPayload(keys: [ENTemporaryExposureKey]) -> Promise<String> {
        return self.deviceCheckService.generatePayload(
            bundleID: TemporaryExposureKeys.Default.appPackageName,
            exposureKeys: keys.map({ $0.keyData }),
            regions: TemporaryExposureKeys.Default.regions
        )
    }
    
    // MARK: - Auth
    
    private func getToken(usingAuthCode authCode: String) -> Promise<String> {
        let data = TemporaryExposureKeysAuthData(code: authCode)
        return renewableRequest.make(target: .auth(data))
            .then { response -> Promise<String> in
                do {
                    let token = try response.map(TemporaryExposureKeysAuthResponse.self).result.accessToken
                    return .value(token)
                } catch {
                    throw error
                }
        }
    }
    
    private func discardOldKeys(key: ENTemporaryExposureKey) -> Bool {
        let startOfDay = UInt32(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)
        let valid = (key.rollingStartNumber * 600) > (startOfDay - 14 * 86400)
        if !valid { console(">>> Discarded Key> Rolling Start Number: \(key.rollingStartNumber), Rolling Period: \(key.rollingPeriod)", type: .warning) }
        return valid
    }
}
