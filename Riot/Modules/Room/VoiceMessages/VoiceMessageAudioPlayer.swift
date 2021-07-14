// 
// Copyright 2021 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

protocol VoiceMessageAudioPlayerDelegate: AnyObject {
    func audioPlayerDidStartLoading(_ audioPlayer: VoiceMessageAudioPlayer)
    func audioPlayerDidFinishLoading(_ audioPlayer: VoiceMessageAudioPlayer)
    
    func audioPlayerDidStartPlaying(_ audioPlayer: VoiceMessageAudioPlayer)
    func audioPlayerDidPausePlaying(_ audioPlayer: VoiceMessageAudioPlayer)
    func audioPlayerDidStopPlaying(_ audioPlayer: VoiceMessageAudioPlayer)
    func audioPlayerDidFinishPlaying(_ audioPlayer: VoiceMessageAudioPlayer)
    
    func audioPlayer(_ audioPlayer: VoiceMessageAudioPlayer, didFailWithError: Error)
}

enum VoiceMessageAudioPlayerError: Error {
    case genericError
}

class VoiceMessageAudioPlayer: NSObject {
    
    private var playerItem: AVPlayerItem?
    private var audioPlayer: AVPlayer?
    
    private var statusObserver: NSKeyValueObservation?
    private var playbackBufferEmptyObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var playToEndObsever: NSObjectProtocol?
    
    private let delegateContainer = DelegateContainer()
    
    private(set) var url: URL?
    
    var isPlaying: Bool {
        guard let audioPlayer = audioPlayer else {
            return false
        }
        
        return (audioPlayer.rate > 0)
    }
    
    var duration: TimeInterval {
        guard let item = self.audioPlayer?.currentItem else {
            return 0
        }
        
        let duration = CMTimeGetSeconds(item.duration)
        
        return duration.isNaN ? 0.0 : duration
    }
    
    var currentTime: TimeInterval {
        guard let audioPlayer = self.audioPlayer else {
            return 0.0
        }
        
        let currentTime = CMTimeGetSeconds(audioPlayer.currentTime())
        
        return currentTime.isNaN ? 0.0 : currentTime
    }
    
    private(set) var isStopped = true
    
    deinit {
        removeObservers()
    }
    
    func loadContentFromURL(_ url: URL) {
        if self.url == url {
            return
        }
        
        self.url = url
        
        removeObservers()
        
        delegateContainer.notifyDelegatesWithBlock { delegate in
            (delegate as? VoiceMessageAudioPlayerDelegate)?.audioPlayerDidStartLoading(self)
        }
        
        playerItem = AVPlayerItem(url: url)
        audioPlayer = AVPlayer(playerItem: playerItem)
        
        addObservers()
    }
    
    func unloadContent() {
        url = nil
        audioPlayer?.replaceCurrentItem(with: nil)
    }
    
    func play() {
        isStopped = false
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
        } catch {
            MXLog.error("Could not redirect audio playback to speakers.")
        }
        
        audioPlayer?.play()
    }
    
    func pause() {
        audioPlayer?.pause()
    }
    
    func stop() {
        isStopped = true
        audioPlayer?.pause()
        audioPlayer?.seek(to: .zero)
    }
    
    func seekToTime(_ time: TimeInterval) {
        audioPlayer?.seek(to: CMTime(seconds: time, preferredTimescale: 60000))
    }
    
    func registerDelegate(_ delegate: VoiceMessageAudioPlayerDelegate) {
        delegateContainer.registerDelegate(delegate)
    }
    
    func deregisterDelegate(_ delegate: VoiceMessageAudioPlayerDelegate) {
        delegateContainer.deregisterDelegate(delegate)
    }
    
    // MARK: - Private
    
    private func addObservers() {
        guard let audioPlayer = audioPlayer, let playerItem = playerItem else {
            return
        }
        
        statusObserver = playerItem.observe(\.status, options: [.old, .new]) { [weak self] item, change in
            guard let self = self else { return }
            
            switch playerItem.status {
            case .failed:
                self.delegateContainer.notifyDelegatesWithBlock { delegate in
                    (delegate as? VoiceMessageAudioPlayerDelegate)?.audioPlayer(self, didFailWithError: playerItem.error ?? VoiceMessageAudioPlayerError.genericError)
                }
            case .readyToPlay:
                self.delegateContainer.notifyDelegatesWithBlock { delegate in
                    (delegate as? VoiceMessageAudioPlayerDelegate)?.audioPlayerDidFinishLoading(self)
                }
            default:
                break
            }
        }
        
        playbackBufferEmptyObserver = playerItem.observe(\.isPlaybackBufferEmpty, options: [.old, .new]) { [weak self] item, change in
            guard let self = self else { return }
            
            if playerItem.isPlaybackBufferEmpty {
                self.delegateContainer.notifyDelegatesWithBlock { delegate in
                    (delegate as? VoiceMessageAudioPlayerDelegate)?.audioPlayerDidStartLoading(self)
                }
            } else {
                self.delegateContainer.notifyDelegatesWithBlock { delegate in
                    (delegate as? VoiceMessageAudioPlayerDelegate)?.audioPlayerDidFinishLoading(self)
                }
            }
        }
        
        rateObserver = audioPlayer.observe(\.rate, options: [.old, .new]) { [weak self] player, change in
            guard let self = self else { return }
            
            if audioPlayer.rate == 0.0 {
                if self.isStopped {
                    self.delegateContainer.notifyDelegatesWithBlock { delegate in
                        (delegate as? VoiceMessageAudioPlayerDelegate)?.audioPlayerDidStopPlaying(self)
                    }
                } else {
                    self.delegateContainer.notifyDelegatesWithBlock { delegate in
                        (delegate as? VoiceMessageAudioPlayerDelegate)?.audioPlayerDidPausePlaying(self)
                    }
                }
            } else {
                self.delegateContainer.notifyDelegatesWithBlock { delegate in
                    (delegate as? VoiceMessageAudioPlayerDelegate)?.audioPlayerDidStartPlaying(self)
                }
            }
        }
        
        playToEndObsever = NotificationCenter.default.addObserver(forName: Notification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem, queue: nil) { [weak self] notification in
            guard let self = self else { return }
            
            self.delegateContainer.notifyDelegatesWithBlock { delegate in
                (delegate as? VoiceMessageAudioPlayerDelegate)?.audioPlayerDidFinishPlaying(self)
            }
        }
    }
    
    private func removeObservers() {
        statusObserver?.invalidate()
        playbackBufferEmptyObserver?.invalidate()
        rateObserver?.invalidate()
        NotificationCenter.default.removeObserver(playToEndObsever as Any)
    }
}

extension VoiceMessageAudioPlayerDelegate {
    func audioPlayerDidStartLoading(_ audioPlayer: VoiceMessageAudioPlayer) { }
    
    func audioPlayerDidFinishLoading(_ audioPlayer: VoiceMessageAudioPlayer) { }
    
    func audioPlayerDidStartPlaying(_ audioPlayer: VoiceMessageAudioPlayer) { }
    
    func audioPlayerDidPausePlaying(_ audioPlayer: VoiceMessageAudioPlayer) { }
    
    func audioPlayerDidStopPlaying(_ audioPlayer: VoiceMessageAudioPlayer) { }
    
    func audioPlayerDidFinishPlaying(_ audioPlayer: VoiceMessageAudioPlayer) { }
    
    func audioPlayer(_ audioPlayer: VoiceMessageAudioPlayer, didFailWithError: Error) { }
}
