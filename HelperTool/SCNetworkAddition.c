/*
 * Copyright (c), MM Weiss
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without modification, 
 * are permitted provided that the following conditions are met:
 * 
 *     1. Redistributions of source code must retain the above copyright notice, 
 *     this list of conditions and the following disclaimer.
 *     
 *     2. Redistributions in binary form must reproduce the above copyright notice, 
 *     this list of conditions and the following disclaimer in the documentation 
 *     and/or other materials provided with the distribution.
 *     
 *     3. Neither the name of the MM Weiss nor the names of its contributors 
 *     may be used to endorse or promote products derived from this software without 
 *     specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY 
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT 
 * SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT 
 * OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR 
 * TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, 
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 *  SCNetworkAddition.c
 *  SCNetworkAddition
 *
 *  Created by mmw on 6/8/09.
 *  Copyright 2009 Cucurbita. All rights reserved.
 *
 */

#include "SCNetworkAddition.h"

#include <sys/types.h>
#include <sys/socket.h>
#include <ifaddrs.h>

#include <netinet/in.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <libkern/OSAtomic.h>

#include <net/if_media.h>
#include <sys/ioctl.h>

static OSSpinLock _SCNADataLock = OS_SPINLOCK_INIT;

CF_INLINE void _SCNASpinLock(OSSpinLock *lockp) {
    OSSpinLockLock(lockp);
}

CF_INLINE void _SCNASpinUnlock(OSSpinLock *lockp) {
    OSSpinLockUnlock(lockp);
}

static CFDictionaryRef _SCNANetworkInterfaceAddresses = NULL;

typedef enum {
	_SCNAInternetAddress4Type = 0,
	_SCNAInternetAddress6Type = 1
} _SCNAInternetAddressType;

#define _kSCNAInternetAddress4Key CFSTR("inet4")
#define _kSCNAInternetAddress6Key CFSTR("inet6")

CF_INLINE CFStringRef _SCNACFStringCreateDefaultWithCString(const char *cStr) {
	return CFStringCreateWithCString(kCFAllocatorDefault, cStr, kCFStringEncodingUTF8);
}

CF_INLINE CFMutableDictionaryRef _SCNACFDictionaryCreateDefaultMutable(void) {
	return CFDictionaryCreateMutable(kCFAllocatorDefault, 0, 
		&kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

CF_INLINE CFDictionaryRef _SCNACFDictionaryCreateDefaultCopy(CFDictionaryRef theDictionary) {
	return CFDictionaryCreateCopy(kCFAllocatorDefault, theDictionary);
}

CF_INLINE CFMutableArrayRef _SCNACFArrayCreateDefaultMutable(void) {
	return CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
}

CF_INLINE CFArrayRef _SCNACFArrayCreateDefaultCopy(CFArrayRef theArray) {
	return CFArrayCreateCopy(kCFAllocatorDefault, theArray);
}

CF_INLINE Boolean _SCNACStringIsStringStartWithString(const char *cStr1, const char *cStr2) {
	while(*cStr1 && *cStr2) {if(*cStr1++ != *cStr2++) { return false; }}; return true;
}

CF_INLINE const char *_SCNACStringWithInternetAddress6(struct in6_addr in) {
	static char buff[INET6_ADDRSTRLEN];
	return inet_ntop(AF_INET6, &in, buff, INET6_ADDRSTRLEN);
}

CF_INLINE const char *_SCNACStringMediaStatusWithBSDDeviceName(const char *devname) {
	struct ifmediareq ifm;
	const char * status;
	
	memset(&ifm, 0, sizeof(struct ifmediareq));
	strncpy(ifm.ifm_name, devname, IFNAMSIZ);
	int s = socket(AF_INET, SOCK_DGRAM, 0);
	ioctl(s, SIOCGIFMEDIA, &ifm);
	
	switch (IFM_TYPE(ifm.ifm_active)) {
		case IFM_FDDI:
		case IFM_TOKEN:
			if (_SCNACStringIsStringStartWithString(devname, "fw")) {
				status = (ifm.ifm_status & IFM_ACTIVE) ? "Active FireWire" : "Inactive FireWire";
			} else {
				status = (ifm.ifm_status & IFM_ACTIVE) ? "Active Modem" : "Inactive Modem";
			}
		break;
		case IFM_IEEE80211:
			status = (ifm.ifm_status & IFM_ACTIVE) ? "Active Airport" : "Inactive Airport";
		break;
		default:
			if (_SCNACStringIsStringStartWithString(devname, "en")) {
				status = (ifm.ifm_status & IFM_ACTIVE) ? "Active Ethernet" : "Inactive Ethernet";
			} else {
				status = (ifm.ifm_status & IFM_ACTIVE) ? "Active" : "Inactive";
			}
	}
	
	return status;
}

CF_INLINE void _SCNANetworkInterfaceAddressesRelease()
{
	if (_SCNANetworkInterfaceAddresses) {
		_SCNASpinLock(&_SCNADataLock);
		CFRelease(_SCNANetworkInterfaceAddresses);
		_SCNANetworkInterfaceAddresses = NULL;
		_SCNASpinUnlock(&_SCNADataLock);
	}
}

CF_INLINE CFDictionaryRef _SCNANetworkInterfaceAddressesCreate()
{	
	CFMutableDictionaryRef ifaces = NULL, iface = NULL;
	CFMutableArrayRef n4 = NULL, n6 = NULL;
	struct ifaddrs *array, *addrs;
	Boolean ifaceRelease = false, n4Release = false, n6Release = false;
	CFStringRef ifaName;
	CFStringRef item;
	
	if (NULL != _SCNANetworkInterfaceAddresses) {
		_SCNASpinLock(&_SCNADataLock);
		_SCNANetworkInterfaceAddresses = CFRetain(_SCNANetworkInterfaceAddresses);
		_SCNASpinUnlock(&_SCNADataLock);
		return _SCNANetworkInterfaceAddresses;
	}
	
	getifaddrs(&array);
	if (!array) {
		return NULL;
	}
	ifaces = _SCNACFDictionaryCreateDefaultMutable();

	for(addrs = array; addrs != NULL; addrs = addrs->ifa_next) {	
		ifaName = _SCNACFStringCreateDefaultWithCString(addrs->ifa_name);
		ifaceRelease = false;
		if (!(iface = (CFMutableDictionaryRef)CFDictionaryGetValue(ifaces, ifaName))) {
			ifaceRelease = true;
			iface = _SCNACFDictionaryCreateDefaultMutable();
			
			item = _SCNACFStringCreateDefaultWithCString(
				_SCNACStringMediaStatusWithBSDDeviceName(addrs->ifa_name)
			);
				
			CFDictionarySetValue(iface, CFSTR("status"), item);
			CFRelease(item);
		}
		
		n4Release = false;
		n6Release = false;
		
		switch(addrs->ifa_addr->sa_family) {
			case AF_INET:
				if (!(n4 = (CFMutableArrayRef)CFDictionaryGetValue(iface, _kSCNAInternetAddress4Key))) {
					n4Release = true;
					n4 = _SCNACFArrayCreateDefaultMutable();
				}
	
				item = _SCNACFStringCreateDefaultWithCString(
					inet_ntoa(((struct sockaddr_in *)addrs->ifa_addr)->sin_addr)
				);
				
				CFArrayAppendValue(n4, item);
				CFRelease(item);
				
				if (n4Release) {
					CFDictionarySetValue(iface, _kSCNAInternetAddress4Key, n4);
					CFRelease(n4);
				}
				
				item = _SCNACFStringCreateDefaultWithCString(
					inet_ntoa(((struct sockaddr_in *)addrs->ifa_netmask)->sin_addr)
				);
				
				CFDictionarySetValue(iface, CFSTR("netmask"), item);
				CFRelease(item);
				
				item = _SCNACFStringCreateDefaultWithCString(
					inet_ntoa(((struct sockaddr_in *)addrs->ifa_broadaddr)->sin_addr)
				);
				
				CFDictionarySetValue(iface, CFSTR("broadcast"), item);
				CFRelease(item);
				
			break;
			case AF_INET6:
				if (!(n6 = (CFMutableArrayRef)CFDictionaryGetValue(iface, _kSCNAInternetAddress6Key))) {
					n6Release = true;
					n6 = _SCNACFArrayCreateDefaultMutable();
				}
				
				item = _SCNACFStringCreateDefaultWithCString(
					_SCNACStringWithInternetAddress6(((struct sockaddr_in6 *)addrs->ifa_addr)->sin6_addr)
				);
				
				CFArrayAppendValue(n6, item);
				CFRelease(item);
				
				if (n6Release) {
					CFDictionarySetValue(iface, _kSCNAInternetAddress6Key, n6);
					CFRelease(n6);
				}
				
			break;
			case AF_LINK:
				if (_SCNACStringIsStringStartWithString(addrs->ifa_name, "en")) {
					unsigned char *m = (unsigned char*)LLADDR((struct sockaddr_dl *)addrs->ifa_addr);
					char buffer[18];
					sprintf(buffer, "%02x:%02x:%02x:%02x:%02x:%02x", m[0], m[1], m[2], m[3], m[4], m[5]);
					item = _SCNACFStringCreateDefaultWithCString(
						buffer
					);
					
					CFDictionarySetValue(iface, CFSTR("ether"), item);
					CFRelease(item);
				}
			break;
		}
		
		CFDictionarySetValue(ifaces, ifaName, iface);
		if (ifaceRelease) {
			CFRelease(iface);
		}
		CFRelease(ifaName);
	}
	
	if(array)
		freeifaddrs(array);
	
	_SCNANetworkInterfaceAddresses = CFRetain(_SCNACFDictionaryCreateDefaultCopy(ifaces));
	CFRelease(ifaces);
	
	return _SCNANetworkInterfaceAddresses;
}

CF_INLINE CFArrayRef _SCNANetworkInterfaceCopyInetAddresses(SCNetworkInterfaceRef interface, _SCNAInternetAddressType inetType)
{
	CFDictionaryRef ifaces = NULL, iface = NULL;
	CFArrayRef inet = NULL, result = NULL;
	CFStringRef ifaName = SCNetworkInterfaceGetBSDName(interface);
	
	if (ifaName) {
		if ((ifaces = _SCNANetworkInterfaceAddressesCreate())) {
			if ((iface = (CFDictionaryRef)CFDictionaryGetValue(ifaces, ifaName))) {
				if ((inet = (CFArrayRef)CFDictionaryGetValue(iface, 
						inetType ? _kSCNAInternetAddress6Key : _kSCNAInternetAddress4Key))) {
					if (CFArrayGetCount(inet)) {
						result = _SCNACFArrayCreateDefaultCopy(inet);
					}
				}
			}
			
			CFRelease(ifaces);
		}
	}
	
	return result;
}

CFArrayRef SCNetworkInterfaceCopyInet4Addresses(SCNetworkInterfaceRef interface)
{
	if (interface) {
		return _SCNANetworkInterfaceCopyInetAddresses(
			interface, 
			_SCNAInternetAddress4Type
		);
	}
	
	return NULL;
}

CFArrayRef SCNetworkInterfaceCopyInet6Addresses(SCNetworkInterfaceRef interface)
{
	if (interface) {
		return _SCNANetworkInterfaceCopyInetAddresses(
			interface, 
			_SCNAInternetAddress6Type
		);
	}
	
	return NULL;
}

CFDictionaryRef SCNetworkInterfaceCopyAllAddresses()
{
	CFDictionaryRef ifaces = NULL, result = NULL;
	
	if ((ifaces = _SCNANetworkInterfaceAddressesCreate())) {
		result = _SCNACFDictionaryCreateDefaultCopy(ifaces);
		CFRelease(ifaces);
	}
	
	return result;
}

void SCNetworkInterfaceInetAddressesRefresh()
{
	_SCNANetworkInterfaceAddressesRelease();
	
	CFDictionaryRef ifaces = NULL;
	
	if ((ifaces = _SCNANetworkInterfaceAddressesCreate())) {
		CFRelease(ifaces);
	}
}

/* EOF */

