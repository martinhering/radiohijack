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

#ifndef TINS_RAWPDU_H
#define TINS_RAWPDU_H

#include <vector>
#include <string>
#include "pdu.h"

namespace Tins {

    /** \brief Represents a PDU which holds raw data.
     *
     * In order to send payloads over TCP, UDP, or other transport layer or
     * higher level protocols, RawPDU can be used as a wrapper for raw byte arrays.
     */
    class RawPDU : public PDU {
    public:
        /**
         * The type used to store the payload.
         */
        typedef std::vector<uint8_t> payload_type;
        
        /**
         * This PDU's flag.
         */
        static const PDU::PDUType pdu_flag = PDU::RAW;
    
        /** 
         * \brief Creates an instance of RawPDU.
         *
         * The payload is copied, therefore the original payload's memory
         * must be freed by the user.
         * \param pload The payload which the RawPDU will contain.
         * \param size The size of the payload.
         */
        RawPDU(const uint8_t *pload, uint32_t size);
        
        /** 
         * \brief Creates an instance of RawPDU from an input string.
         * 
         * \param data The content of the payload.
         */
        RawPDU(const std::string &data);

        /**
         * \brief Setter for the payload field
         * \param pload The payload to be set.
         */
        void payload(const payload_type &pload);

        /**
         * \brief Setter for the payload field
         * \param start The start of the new payload.
         * \param end The end of the new payload.
         */
        template<typename ForwardIterator>
        void payload(ForwardIterator start, ForwardIterator end) {
            _payload.assign(start, end);
        }

        /** 
         * \brief Const getter for the payload.
         * \return The RawPDU's payload.
         */
        const payload_type &payload() const { return _payload; }
        
        /** 
         * \brief Non-const getter for the payload.
         * \return The RawPDU's payload.
         */
        payload_type &payload() { return _payload; }
        
        /** 
         * \brief Returns the header size.
         * 
         * This returns the same as RawPDU::payload_size().
         *
         * This metod overrides PDU::header_size. \sa PDU::header_size
         */
        uint32_t header_size() const;
        
        /** 
         * \brief Returns the payload size.
         *
         * \return uint32_t containing the payload size.
         */
        uint32_t payload_size() const {
            return _payload.size();
        }

        /**
         * \brief Check wether ptr points to a valid response for this PDU.
         *
         * This always returns true, since we don't know what this 
         * RawPDU is holding.
         * 
         * \sa PDU::matches_response
         * \param ptr The pointer to the buffer.
         * \param total_sz The size of the buffer.
         */
        bool matches_response(const uint8_t *ptr, uint32_t total_sz) const;

        /**
         * \brief Getter for the PDU's type.
         * \sa PDU::pdu_type
         */
        PDUType pdu_type() const { return PDU::RAW; }
        
        /**
         * \brief Constructs the given PDU type from the raw data stored
         * in this RawPDU.
         */
        template<typename T>
        T to() const {
            return T(&_payload[0], _payload.size());
        }
        
        /**
         * \sa PDU::clone
         */
        RawPDU *clone() const {
            return new RawPDU(*this);
        }
    private:
        void write_serialization(uint8_t *buffer, uint32_t total_sz, const PDU *parent);

        payload_type _payload;
    };
}


#endif // TINS_RAWPDU_H
