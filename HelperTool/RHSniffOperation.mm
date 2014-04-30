//
//  RHSniffOperation.m
//  RadioHijack
//
//  Created by Martin Hering on 29.04.14.
//  Copyright (c) 2014 Vemedio. All rights reserved.
//

#import "RHSniffOperation.h"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"
#pragma clang diagnostic ignored "-Wunused-parameter"
#pragma clang diagnostic ignored "-Wshadow"
#import "tins.h"
#pragma clang diagnostic pop

extern "C" {
#import "SCNetworkAddition.h"
};




using namespace Tins;

@interface RHSniffOperation ()
@property (nonatomic, strong) NSString* networkInterface;
@property (nonatomic, strong) NSDictionary* networkInterfaceProperties;
@property (nonatomic, strong) NSMutableDictionary* requestMap;
@property (nonatomic, strong) NSMutableDictionary* responseDataMap;
@end


@implementation RHSniffOperation

bool handle(PDU &some_pdu);

+ (NSSet*) activeNetworkInterfaces
{
    NSMutableSet* activeInterfaces = [NSMutableSet new];
    NSDictionary* interfaces = (__bridge_transfer NSDictionary*)SCNetworkInterfaceCopyAllAddresses();
    
    for(NSString* interfaceKey in interfaces)
    {
        NSDictionary* values = interfaces[interfaceKey];
        if ([values[@"status"] rangeOfString:@"Active"].location != NSNotFound) {
            [activeInterfaces addObject:interfaceKey];
        }
    }
    
    return activeInterfaces;
}

- (id) initWithNetworkInterface:(NSString*)networkInterface
{
    if ((self = [self init])) {
        _networkInterface = networkInterface;
        
        NSDictionary* interfaces = (__bridge_transfer NSDictionary*)SCNetworkInterfaceCopyAllAddresses();
        _networkInterfaceProperties = interfaces[networkInterface];
        
        _requestMap = [[NSMutableDictionary alloc] init];
        _responseDataMap = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (BOOL) _ipAddressIsSourceAddress:(NSString*)address
{
    NSArray* ipv4Address = self.networkInterfaceProperties[@"inet4"];
    NSArray* ipv6Address = self.networkInterfaceProperties[@"inet6"];
    return ([ipv4Address containsObject:address] || [ipv6Address containsObject:address]);
}

- (NSURLRequest*) _parseHTTPRequestWithData:(NSData*)data
{
    NSString* string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray* lines = [string componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    NSString* path;
    NSString* host;
    NSString* method;
    NSMutableDictionary* headers = [[NSMutableDictionary alloc] init];

    NSInteger lineIndex = 0;
    for(NSString* line in lines)
    {
        if ([line length] == 0) {
            continue;
        }
        
        if (lineIndex == 0)
        {
            NSArray* comps = [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([comps count] >= 2) {
                method = comps[0];
                path = comps[1];
            }
        }
        else
        {
            NSUInteger separatorLocation = [line rangeOfString:@":"].location;
            if (separatorLocation == NSNotFound) {
                continue;
            }
            
            NSString* key = [line substringToIndex:separatorLocation];
            NSString* value = [[line substringFromIndex:separatorLocation+1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            if ([key caseInsensitiveCompare:@"host"] == NSOrderedSame) {
                host = value;
            }
            [headers setObject:value forKey:key];
        }
        lineIndex++;
    }
    
    if (!host || !path) {
        return nil;
    }
    
    NSString* urlString = [NSString stringWithFormat:@"http://%@%@", host, path];
    NSURL* url = [NSURL URLWithString:urlString];
    
    
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setAllHTTPHeaderFields:headers];
    
    return request;
}

- (NSHTTPURLResponse*) _parseHTTPResponseWithData:(NSData*)data requestURL:(NSURL*)url
{
    NSString* string = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    NSArray* lines = [string componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    NSInteger statusCode=0;
    NSString* httpVersion;
    
    NSMutableDictionary* headers = [[NSMutableDictionary alloc] init];
    
    NSInteger lineIndex = 0;
    NSInteger emptyLines = 0;
    for(NSString* line in lines)
    {
        if ([line length] == 0) {
            emptyLines++;
            if (emptyLines > 1) {
                break;
            }
            continue;
        }
        
        emptyLines = 0;
        
        if (lineIndex == 0)
        {
            NSArray* comps = [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([comps count] >= 2) {
                httpVersion = comps[0];
                statusCode = [comps[1] integerValue];
            }
        }
        else
        {
            NSUInteger separatorLocation = [line rangeOfString:@":"].location;
            if (separatorLocation == NSNotFound) {
                continue;
            }
            
            NSString* key = [line substringToIndex:separatorLocation];
            NSString* value = [[line substringFromIndex:separatorLocation+1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            [headers setObject:value forKey:key];
        }
        lineIndex++;
    }
    
    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:statusCode HTTPVersion:httpVersion headerFields:headers];
 
    return response;
}

static RHSniffOperation* me;

- (void) _handlePDU:(PDU&)some_pdu
{
    const EthernetII &ethernet = some_pdu.rfind_pdu<EthernetII>();
    const IP &ip = some_pdu.rfind_pdu<IP>();
    const TCP &tcp = some_pdu.rfind_pdu<TCP>();
    
    // filter for HTTP traffic
//    if (tcp.sport() != 80 && tcp.dport() != 80) {
//        return;
//    }
    
    
    PDU::serialization_type buffer = some_pdu.serialize();
    uint32_t ethernet_headerSize = ethernet.header_size();
    uint32_t ip_headerSize = ip.header_size();
    uint32_t tcp_headerSize = tcp.header_size();
    
    
    NSString* srcAddress = [[NSString alloc] initWithUTF8String:ip.src_addr().to_string().c_str()];
    NSString* dstAddress = [[NSString alloc] initWithUTF8String:ip.dst_addr().to_string().c_str()];
    
    BOOL isRequest = [self _ipAddressIsSourceAddress:srcAddress];
    BOOL isResponse = [self _ipAddressIsSourceAddress:dstAddress];
    
    
    if (tcp.flags() == (TCP::SYN | TCP::ACK)) {
        //std::cout << ip.src_addr() << ":" << tcp.sport() << " -> " << ip.dst_addr() << ":" << tcp.dport() << "  SYN+ACK: seq=" << tcp.seq() << "; ack=" << tcp.ack_seq() << std::endl;
    }
    else if (tcp.flags() == TCP::SYN) {
        //std::cout << ip.src_addr() << ":" << tcp.sport() << " -> " << ip.dst_addr() << ":" << tcp.dport() << "  SYN: seq=" << tcp.seq() << std::endl;
    }
    else if (tcp.flags() == (TCP::FIN)) {
        //std::cout << ip.src_addr() << ":" << tcp.sport() << " -> " << ip.dst_addr() << ":" << tcp.dport() << "  FIN: seq=" << tcp.seq() << "; ack=" << tcp.ack_seq() << std::endl;
    }
    else
    {
        NSMutableData* tcpPayload = [[NSMutableData alloc] initWithCapacity:buffer.size()];
        PDU::serialization_type::iterator start = buffer.begin() + ethernet_headerSize + ip_headerSize + tcp_headerSize;
        for (PDU::serialization_type::iterator it = start ; it != buffer.end(); ++it) {
            [tcpPayload appendBytes:&(*it) length:1];
        }
        
        if (isRequest && [tcpPayload length] > 0)
        {
            NSURLRequest* request = [self _parseHTTPRequestWithData:tcpPayload];
            NSInteger ack = (NSInteger)tcp.ack_seq();
            if (request) {
                [self.requestMap setObject:request forKey:@(ack)];
            }
            
            /*
            if (request && self.didFindHTTPRequest) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.didFindHTTPRequest(request);
                });
            }
             */
        }
        
        else if (isResponse && [tcpPayload length] > 0)
        {
            NSInteger seq = (NSInteger)tcp.seq();
            NSInteger ackSeq = (NSInteger)tcp.ack_seq();
            
            NSURLRequest* request = self.requestMap[@(seq)];
            
            if (request)
            {
                NSMutableData* data = self.responseDataMap[@(ackSeq)];
                if (!data) {
                    data = tcpPayload;
                }
                else {
                    [data appendData:tcpPayload];
                }
                
                
                NSString* tcpPayloadString = [[NSString alloc] initWithData:tcpPayload encoding:NSUTF8StringEncoding];
                BOOL headerFinished = ([tcpPayloadString rangeOfString:@"\r\n\r\n"].location != NSNotFound);
                
                //NSLog(@"headerFinished: %ld   data: %ld", (long)headerFinished, [data length]);
                
                if (headerFinished)
                {
                    NSHTTPURLResponse* response = [self _parseHTTPResponseWithData:data requestURL:request.URL];
                    //NSLog(@"request: %@, response: %@", request, response);
                    
                    if (self.didReceiveHTTPRequestResponse) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            self.didReceiveHTTPRequestResponse(request, response);
                        });
                    }
                    
                    [self.requestMap removeObjectForKey:@(seq)];
                    [self.responseDataMap removeObjectForKey:@(ackSeq)];
                }
                else
                {
                    self.responseDataMap[@(ackSeq)] = data;
                    
                    // rewrite seq to next packet
                    self.requestMap[@(seq+[data length])] = request;
                    [self.requestMap removeObjectForKey:@(seq)];
                }
            }
        }

//        std::string payload(buffer.begin() + ethernet_headerSize + ip_headerSize + tcp_headerSize, buffer.end());
//        std::cout << ip.src_addr() << ":" << tcp.sport() << " -> " << ip.dst_addr() << ":" << tcp.dport() << "  seq=" << tcp.seq() << "; ack=" << tcp.ack_seq() << "  Payload: " << payload << std::endl;
    }
}

bool handle(PDU &some_pdu)
{
    // Don't process anything
    try
    {
        [me _handlePDU:some_pdu];
        
    }
    catch (int e)
    {
        std::cout << "An exception occurred. Exception Nr. " << e << '\n';
    }
    return (![me isCancelled]);
}

- (void) main
{
    @autoreleasepool {
        
        me = self;
        
        //NSSet* localAddess = [RHSniffOperation localIPv4Addresses];
        
        NSLog(@"started: %@", self.networkInterface);
        
        Sniffer sniffer([self.networkInterface UTF8String], Sniffer::PROMISC);
        sniffer.sniff_loop(&handle);
        
        
        NSLog(@"ended");
    }
    
}
@end
