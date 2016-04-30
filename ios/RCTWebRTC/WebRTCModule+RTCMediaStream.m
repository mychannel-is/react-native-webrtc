//
//  WebRTCModule+RTCMediaStream.m
//
//  Created by one on 2015/9/24.
//  Copyright © 2015 One. All rights reserved.
//

#import <objc/runtime.h>

#import "RTCVideoCapturer.h"
#import "RTCVideoSource.h"
#import "RTCVideoTrack.h"
#import "RTCPair.h"
#import "RTCMediaConstraints.h"

#import "WebRTCModule+RTCMediaStream.h"
#import "WebRTCModule+RTCPeerConnection.h"

@implementation RTCMediaStream (React)
- (NSNumber *)reactTag {
  return objc_getAssociatedObject(self, _cmd);
}
- (void)setReactTag:(NSNumber *)reactTag {
  objc_setAssociatedObject(self, @selector(reactTag), reactTag, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
@end

@implementation RTCVideoTrack (React)
- (NSNumber *)reactTag{
  return objc_getAssociatedObject(self, _cmd);
}
- (void)setReactTag:(NSNumber *)reactTag {
  objc_setAssociatedObject(self, @selector(reactTag), reactTag, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
@end

@implementation RTCAudioTrack (React)
- (NSNumber *)reactTag {
  return objc_getAssociatedObject(self, _cmd);
}
- (void)setReactTag:(NSNumber *)reactTag {
  objc_setAssociatedObject(self, @selector(reactTag), reactTag, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
@end

@implementation AVCaptureDevice (React)

- (NSString*)positionString {
  switch (self.position) {
    case AVCaptureDevicePositionUnspecified: return @"unspecified";
    case AVCaptureDevicePositionBack: return @"back";
    case AVCaptureDevicePositionFront: return @"front";
  }
  return nil;
}

@end

@implementation WebRTCModule (RTCMediaStream)

RCT_EXPORT_METHOD(getUserMedia:(NSDictionary *)constraints callback:(RCTResponseSenderBlock)callback)
{
  NSNumber *objectID = @(self.mediaStreamId++);

  NSMutableArray *tracks = [NSMutableArray array];

  RTCMediaStream *mediaStream = [self.peerConnectionFactory mediaStreamWithLabel:@"ARDAMS"];
    NSMutableArray *mandatoryConstraints = [NSMutableArray new];
    RTCMediaConstraints *mediaStreamConstraints = [self defaultMediaStreamConstraints];

  if (constraints[@"audio"] && [constraints[@"audio"] boolValue]) {
    RTCAudioTrack *audioTrack = [self.peerConnectionFactory audioTrackWithID:@"ARDAMSa0"];
    [mediaStream addAudioTrack:audioTrack];
    NSNumber *trackId = @(self.trackId++);
    audioTrack.reactTag = trackId;
    self.tracks[trackId] = audioTrack;
    [tracks addObject:@{@"id": trackId, @"kind": audioTrack.kind, @"label": audioTrack.label}];
  }

  if (constraints[@"video"]) {
    AVCaptureDevice *videoDevice;
    if ([constraints[@"video"] isKindOfClass:[NSNumber class]]) {
      if ([constraints[@"video"] boolValue]) {
        videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
      }
    } else if ([constraints[@"video"] isKindOfClass:[NSDictionary class]]) {
      NSDictionary *videoOptions = constraints[@"video"];
        NSString *sourceId;
      for(id key in videoOptions){
          NSString *constraintValue = [videoOptions objectForKey:key];
          if(key == @"optional"){
              for (id item in constraintValue) {
                  if ([item isKindOfClass:[NSDictionary class]]) {
                      NSDictionary *dict = item;
                      if (dict[@"sourceId"]) {
                         sourceId = dict[@"sourceId"];
                      }
                  }
              }
              
          }else{
              [mandatoryConstraints addObject:[[RTCPair alloc] initWithKey:key value:constraintValue]];
          }
      }
        
        if(sourceId){
            videoDevice = [AVCaptureDevice deviceWithUniqueID:sourceId];
        }
        if (!videoDevice) {
            videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        }
    }

    if (videoDevice) {
      RTCVideoCapturer *capturer = [RTCVideoCapturer capturerWithDeviceName:[videoDevice localizedName]];
      RTCVideoSource *videoSource = [self.peerConnectionFactory videoSourceWithCapturer:capturer constraints:mediaStreamConstraints];
      RTCVideoTrack *videoTrack = [self.peerConnectionFactory videoTrackWithID:@"ARDAMSv0" source:videoSource];
      [mediaStream addVideoTrack:videoTrack];
      NSNumber *trackId = @(self.trackId++);
      videoTrack.reactTag = trackId;
      self.tracks[trackId] = videoTrack;
      [tracks addObject:@{@"id": trackId, @"kind": videoTrack.kind, @"label": videoTrack.label}];
    }
  }

  mediaStream.reactTag = objectID;
  self.mediaStreams[objectID] = mediaStream;
  callback(@[objectID, tracks]);
}

RCT_EXPORT_METHOD(mediaStreamTrackGetSources:(RCTResponseSenderBlock)callback) {
  NSMutableArray *sources = [NSMutableArray array];
  NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
  for (AVCaptureDevice *device in videoDevices) {
    [sources addObject:@{
                         @"facing": device.positionString,
                         @"id": device.uniqueID,
                         @"label": device.localizedName,
                         @"kind": @"video",
                         }];
  }
  NSArray *audioDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
  for (AVCaptureDevice *device in audioDevices) {
    [sources addObject:@{
                         @"facing": @"",
                         @"id": device.uniqueID,
                         @"label": device.localizedName,
                         @"kind": @"audio",
                         }];
  }
  callback(@[sources]);
}


RCT_EXPORT_METHOD(mediaStreamRelease:(nonnull NSNumber *)streamID)
{
  if (self.mediaStreams[streamID]) {
    RTCMediaStream *mediaStream = self.mediaStreams[streamID];
    for (RTCVideoTrack *track in mediaStream.videoTracks) {
      [self.tracks removeObjectForKey:track.reactTag];
    }
    for (RTCAudioTrack *track in mediaStream.audioTracks) {
      [self.tracks removeObjectForKey:track.reactTag];
    }
    [self.mediaStreams removeObjectForKey:streamID];
  }
}
- (RTCMediaConstraints *)defaultMediaStreamConstraints {
    NSArray *mandatoryConstraints = @[
                                      [[RTCPair alloc] initWithKey:@"maxHeight" value:@"320"],
                                      [[RTCPair alloc] initWithKey:@"maxWidth" value:@"240"]
                                      ];
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:mandatoryConstraints
     optionalConstraints:nil];
    return constraints;
}

@end
