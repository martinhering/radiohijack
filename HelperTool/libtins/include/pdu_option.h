/*
 * Copyright (c) 2012, Matias Fontanini
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 * 
 * * Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * * Redistributions in binary form must reproduce the above
 *   copyright notice, this list of conditions and the following disclaimer
 *   in the documentation and/or other materials provided with the
 *   distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#ifndef TINS_PDU_OPTION_H
#define TINS_PDU_OPTION_H

#include <vector>
#include <iterator>
#include <algorithm>
#include <string>
#include <stdint.h>
#include "exceptions.h"
#include "endianness.h"
#include "internals.h"
#include "ip_address.h"
#include "ipv6_address.h"
#include "hw_address.h"

namespace Tins {
/**
 * \cond
 */
template<typename OptionType, class PDUType>
class PDUOption;

namespace Internals {
    template<typename T, typename X, typename PDUType>
    T convert_to_integral(const PDUOption<X, PDUType> & opt) {
        if(opt.data_size() != sizeof(T))
            throw malformed_option();
        T data = *(T*)opt.data_ptr();
        if(PDUType::endianness == PDUType::BE)
            data = Endian::be_to_host(data);
        else
            data = Endian::le_to_host(data);
        return data;
    }
    
    template<typename T, typename = void>
    struct converter {
        template<typename X, typename PDUType>
        static T convert(const PDUOption<X, PDUType>& opt) {
            return T::from_option(opt);
        }
    };
    
    template<>
    struct converter<uint8_t> {
        template<typename X, typename PDUType>
        static uint8_t convert(const PDUOption<X, PDUType>& opt) {
            if(opt.data_size() != 1)
                throw malformed_option();
            return *opt.data_ptr();
        }
    };
    
    template<>
    struct converter<uint16_t> {
        template<typename X, typename PDUType>
        static uint16_t convert(const PDUOption<X, PDUType>& opt) {
            return convert_to_integral<uint16_t>(opt);
        }
    };
    
    template<>
    struct converter<uint32_t> {
        template<typename X, typename PDUType>
        static uint32_t convert(const PDUOption<X, PDUType>& opt) {
            return convert_to_integral<uint32_t>(opt);
        }
    };
    
    template<>
    struct converter<uint64_t> {
        template<typename X, typename PDUType>
        static uint64_t convert(const PDUOption<X, PDUType>& opt) {
            return convert_to_integral<uint64_t>(opt);
        }
    };

    template<size_t n>
    struct converter<HWAddress<n> > {
        template<typename X, typename PDUType>
        static HWAddress<n> convert(const PDUOption<X, PDUType>& opt) {
            if(opt.data_size() != n)
                throw malformed_option();
            return HWAddress<n>(opt.data_ptr());
        }
    };

    template<>
    struct converter<IPv4Address> {
        template<typename X, typename PDUType>
        static IPv4Address convert(const PDUOption<X, PDUType>& opt) {
            if(opt.data_size() != sizeof(uint32_t))
                throw malformed_option();
            const uint32_t *ptr = (const uint32_t*)opt.data_ptr();
            if(PDUType::endianness == PDUType::BE)
                return IPv4Address(*ptr);
            else
                return IPv4Address(Endian::change_endian(*ptr));
        }
    };

    template<>
    struct converter<IPv6Address> {
        template<typename X, typename PDUType>
        static IPv6Address convert(const PDUOption<X, PDUType>& opt) {
            if(opt.data_size() != IPv6Address::address_size)
                throw malformed_option();
            return IPv6Address(opt.data_ptr());
        }
    };
    
    template<>
    struct converter<std::string> {
        template<typename X, typename PDUType>
        static std::string convert(const PDUOption<X, PDUType>& opt) {
            return std::string(
                opt.data_ptr(),
                opt.data_ptr() + opt.data_size()
            );
        }
    };
    
    template<>
    struct converter<std::vector<float> > {
        template<typename X, typename PDUType>
        static std::vector<float> convert(const PDUOption<X, PDUType>& opt) {
            std::vector<float> output;
            const uint8_t *ptr = opt.data_ptr(), *end = ptr + opt.data_size();
            while(ptr != end) {
                output.push_back(float(*(ptr++) & 0x7f) / 2);
            }
            return output;
        }
    };
    
    template<typename T>
    struct converter<std::vector<T>, typename enable_if<is_unsigned_integral<T>::value>::type> {
        template<typename X, typename PDUType>
        static std::vector<T> convert(const PDUOption<X, PDUType>& opt) {
            if(opt.data_size() % sizeof(T) != 0)
                throw malformed_option();
            const T *ptr = (const T*)opt.data_ptr();
            const T *end = (const T*)(opt.data_ptr() + opt.data_size());
            
            std::vector<T> output(std::distance(ptr, end));
            typename std::vector<T>::iterator it = output.begin();
            while(ptr < end) {
                if(PDUType::endianness == PDUType::BE)
                    *it++ = Endian::be_to_host(*ptr++);
                else
                    *it++ = Endian::le_to_host(*ptr++);
            }
            return output;
        }
    };
    
    template<typename T, typename U>
    struct converter<
            std::vector<std::pair<T, U> >, 
            typename enable_if<
                is_unsigned_integral<T>::value && is_unsigned_integral<U>::value
            >::type
    > {
        template<typename X, typename PDUType>
        static std::vector<std::pair<T, U> > convert(const PDUOption<X, PDUType>& opt) {
            if(opt.data_size() % (sizeof(T) + sizeof(U)) != 0)
                throw malformed_option();
            const uint8_t *ptr = opt.data_ptr(), *end = ptr + opt.data_size();
            
            std::vector<std::pair<T, U> > output;
            while(ptr < end) {
                std::pair<T, U> data;
                data.first = *(const T*)ptr;
                ptr += sizeof(T);
                data.second = *(const U*)ptr;
                ptr += sizeof(U);
                if(PDUType::endianness == PDUType::BE) {
                    data.first = Endian::be_to_host(data.first);
                    data.second = Endian::be_to_host(data.second);
                }
                else {
                    data.first = Endian::le_to_host(data.first);
                    data.second = Endian::le_to_host(data.second);
                }
                output.push_back(data);
            }
            return output;
        }
    };
    
    template<>
    struct converter<std::vector<IPv4Address> > {
        template<typename X, typename PDUType>
        static std::vector<IPv4Address> convert(const PDUOption<X, PDUType>& opt) {
            if(opt.data_size() % 4 != 0)
                throw malformed_option();
            const uint32_t *ptr = (const uint32_t*)opt.data_ptr();
            const uint32_t *end = (const uint32_t*)(opt.data_ptr() + opt.data_size());
            
            std::vector<IPv4Address> output(std::distance(ptr, end));
            std::vector<IPv4Address>::iterator it = output.begin();
            while(ptr < end) {
                if(PDUType::endianness == PDUType::BE)
                    *it++ = IPv4Address(*ptr++);
                else
                    *it++ = IPv4Address(Endian::change_endian(*ptr++));
            }
            return output;
        }
    };
    
    template<>
    struct converter<std::vector<IPv6Address> > {
        template<typename X, typename PDUType>
        static std::vector<IPv6Address> convert(const PDUOption<X, PDUType>& opt) {
            if(opt.data_size() % IPv6Address::address_size != 0)
                throw malformed_option();
            const uint8_t *ptr = opt.data_ptr(), *end = opt.data_ptr() + opt.data_size();
            std::vector<IPv6Address> output;
            while(ptr < end) {
                output.push_back(IPv6Address(ptr));
                ptr += IPv6Address::address_size;
            }
            return output;
        }
    };
    
    template<typename T, typename U>
    struct converter<
            std::pair<T, U>, 
            typename enable_if<
                is_unsigned_integral<T>::value && is_unsigned_integral<U>::value
            >::type
    > {
        template<typename X, typename PDUType>
        static std::pair<T, U> convert(const PDUOption<X, PDUType>& opt) {
            if(opt.data_size() != sizeof(T) + sizeof(U))
                throw malformed_option();
            std::pair<T, U> output;
            output.first = *(const T*)opt.data_ptr();
            output.second = *(const U*)(opt.data_ptr() + sizeof(T));
            if(PDUType::endianness == PDUType::BE) {
                output.first = Endian::be_to_host(output.first);
                output.second = Endian::be_to_host(output.second);
            }
            else {
                output.first = Endian::le_to_host(output.first);
                output.second = Endian::le_to_host(output.second);
            }
            return output;
        }
    };
}

/**
 * \endcond
 */

/**
 * \class PDUOption
 * \brief Represents a PDU option field.
 * 
 * Several PDUs, such as TCP, IP, Dot11 or DHCP contain options. All
 * of them behave exactly the same way. This class represents those
 * options.
 * 
 * The OptionType template parameter indicates the type that will be
 * used to store this option's identifier.
 */
template<typename OptionType, class PDUType>
class PDUOption {
public:
    typedef std::vector<uint8_t> container_type;
    typedef typename container_type::value_type data_type;
    typedef OptionType option_type;

    /**
     * \brief Constructs a PDUOption.
     * \param opt The option type.
     * \param length The option's data length.
     * \param data The option's data(if any).
     */
    PDUOption(option_type opt = option_type(), size_t length = 0, const data_type *data = 0) 
    : option_(opt), size_(length), value_(data, data + (data ? length : 0)) {
        
    }
    
    /**
     * \brief Constructs a PDUOption from iterators, which 
     * indicate the data to be stored in it.
     * 
     * \param opt The option type.
     * \param start The beginning of the option data.
     * \param end The end of the option data.
     */
    template<typename ForwardIterator>
    PDUOption(option_type opt, ForwardIterator start, ForwardIterator end) 
    : option_(opt), size_(std::distance(start, end)), value_(start, end) {
        
    }
    
    /**
     * \brief Constructs a PDUOption from iterators, which 
     * indicate the data to be stored in it.
     * 
     * The length parameter indicates the contents of the length field
     * when this option is serialized. Note that this can be different
     * to std::distance(start, end).
     * 
     * \sa length_field
     * 
     * \param opt The option type.
     * \param length The length of this option.
     * \param start The beginning of the option data.
     * \param end The end of the option data.
     */
    template<typename ForwardIterator>
    PDUOption(option_type opt, size_t length, ForwardIterator start, ForwardIterator end) 
    : option_(opt), size_(length), value_(start, end) {
        
    }
    
    /**
     * Retrieves this option's type.
     * \return uint8_t containing this option's size.
     */
    option_type option() const {
        return option_;
    }
    
    /**
     * Sets this option's type
     * \param opt The option type to be set.
     */
    void option(option_type opt) {
        option_ = opt;
    }
    
    /**
     * Retrieves this option's data.
     * 
     * If this method is called when data_size() == 0, 
     * dereferencing the returned pointer will result in undefined
     * behaviour.
     * 
     * \return const data_type& containing this option's value.
     */
    const data_type *data_ptr() const {
        return &*value_.begin();
    }
    
    /**
     * \brief Retrieves the length of this option's data.
     * 
     * This is the actual size of the data.
     */
    size_t data_size() const {
        return value_.size();
    }
    
    /**
     * \brief Retrieves the data length field.
     * 
     * This is what the size field will contain when this option is 
     * serialized. It can differ from the actual data size. 
     * 
     * This will be equal to data_size unless the constructor that takes
     * both a data length and two iterators is used.

     * 
     * \sa data_size.
     */
    size_t length_field() const {
        return size_;
    }
    
    /**
     * \brief Constructs a T from this PDUOption.
     * 
     * Use this method to convert a PDUOption to the specific type that
     * represents it. For example, if you know an option is of type
     * PDU::SACK, you could use option.to<TCP::sack_type>().
     */
    template<typename T>
    T to() const {
        return Internals::converter<T>::convert(*this);
    }
private:
    option_type option_;
    uint16_t size_;
    container_type value_;
};
} // namespace Tins
#endif // TINS_PDU_OPTION_H
