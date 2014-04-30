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
 *  SCNetworkAddition.h
 *  SCNetworkAddition
 *
 *  Created by mmw on 6/8/09.
 *  Copyright 2009 Cucurbita. All rights reserved.
 *
 */

#include <SystemConfiguration/SystemConfiguration.h>

/*!
	@function SCNetworkInterfaceCopyInet4Addresses
	@discussion Returns ipv4 addresses (dotted format) linked to the interface.
	@param interface The network interface.
	@result The list of ipv4 addresses linked the interface;
		NULL if no ipv4 addresses are supported or linked.
 */
CF_EXPORT 
CFArrayRef SCNetworkInterfaceCopyInet4Addresses(SCNetworkInterfaceRef interface);

/*!
	@function SCNetworkInterfaceCopyInet6Addresses
	@discussion Returns ipv6 addresses (hexa format) linked to the interface.
	@param interface The network interface.
	@result The list of ipv6 addresses linked the interface;
		NULL if no ipv6 addresses are supported or linked.
 */
CF_EXPORT 
CFArrayRef SCNetworkInterfaceCopyInet6Addresses(SCNetworkInterfaceRef interface);

/*!
	@function SCNetworkInterfaceCopyAllAddresses
	@discussion Returns BSD interfaces.
	@result interfaces;
		NULL if no BSD interfaces.
 */
CF_EXPORT
CFDictionaryRef SCNetworkInterfaceCopyAllAddresses(void);

/*!
	@function SCNetworkInterfaceInetAddressesRefresh
	@discussion Reloads the internal interfaces List.
 */
CF_EXPORT
void SCNetworkInterfaceInetAddressesRefresh(void);


/* EOF */

