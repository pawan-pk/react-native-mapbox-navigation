#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(ParticipantsManager, RCTEventEmitter)

RCT_EXTERN_METHOD(updateParticipants:(NSArray *)list)

@end