# cython: language_level=3
# distutils: language = c++

from libc.stdint cimport *

from .ndi_lib cimport *
from .common cimport *
from .types cimport *


cdef extern from "Processing.NDI.structs.h" nogil:


    #// An enumeration to specify the type of a packet returned by the functions.
    enum NDIlib_frame_type_e:
        #// What frame type is this?
        NDIlib_frame_type_none
        NDIlib_frame_type_video
        NDIlib_frame_type_audio
        NDIlib_frame_type_metadata
        NDIlib_frame_type_error

        #// This indicates that the settings on this input have changed. For instance, this value will be returned
        #// from NDIlib_recv_capture_v2 and NDIlib_recv_capture when the device is known to have new settings, for
        #// instance the web URL has changed or the device is now known to be a PTZ camera.
        NDIlib_frame_type_status_change

        #// Make sure this is a 32-bit enumeration.
        # NDIlib_frame_type_max

    #// FourCC values for video frames.
    enum NDIlib_FourCC_video_type_e:
        #// YCbCr color space using 4:2:2.
        NDIlib_FourCC_video_type_UYVY
        NDIlib_FourCC_type_UYVY

        #// YCbCr + Alpha color space, using 4:2:2:4.
        #// In memory there are two separate planes. The first is a regular
        #// UYVY 4:2:2 buffer. Immediately following this in memory is a
        #// alpha channel buffer.
        NDIlib_FourCC_video_type_UYVA
        NDIlib_FourCC_type_UYVA

        #// YCbCr color space using 4:2:2 in 16bpp.
        #// In memory this is a semi-planar format. This is identical to a 16bpp version of the NV16 format.
        #// The first buffer is a 16bpp luminance buffer.
        #// Immediately after this is an interleaved buffer of 16bpp Cb, Cr pairs.
        NDIlib_FourCC_video_type_P216
        NDIlib_FourCC_type_P216

        #// YCbCr color space with an alpha channel, using 4:2:2:4.
        #// In memory this is a semi-planar format.
        #// The first buffer is a 16bpp luminance buffer.
        #// Immediately after this is an interleaved buffer of 16bpp Cb, Cr pairs.
        #// Immediately after is a single buffer of 16bpp alpha channel.
        NDIlib_FourCC_video_type_PA16
        NDIlib_FourCC_type_PA16

        #// Planar 8bit 4:2:0 video format.
        #// The first buffer is an 8bpp luminance buffer.
        #// Immediately following this is a 8bpp Cr buffer.
        #// Immediately following this is a 8bpp Cb buffer.
        NDIlib_FourCC_video_type_YV12
        NDIlib_FourCC_type_YV12

        #// The first buffer is an 8bpp luminance buffer.
        #// Immediately following this is a 8bpp Cb buffer.
        #// Immediately following this is a 8bpp Cr buffer.
        NDIlib_FourCC_video_type_I420
        NDIlib_FourCC_type_I420

        #// Planar 8bit 4:2:0 video format.
        #// The first buffer is an 8bpp luminance buffer.
        #// Immediately following this is in interleaved buffer of 8bpp Cb, Cr pairs
        NDIlib_FourCC_video_type_NV12
        NDIlib_FourCC_type_NV12

        #// Planar 8bit, 4:4:4:4 video format.
        #// Color ordering in memory is blue, green, red, alpha
        NDIlib_FourCC_video_type_BGRA
        NDIlib_FourCC_type_BGRA

        #// Planar 8bit, 4:4:4 video format, packed into 32bit pixels.
        #// Color ordering in memory is blue, green, red, 255
        NDIlib_FourCC_video_type_BGRX
        NDIlib_FourCC_type_BGRX

        #// Planar 8bit, 4:4:4:4 video format.
        #// Color ordering in memory is red, green, blue, alpha
        NDIlib_FourCC_video_type_RGBA
        NDIlib_FourCC_type_RGBA

        #// Planar 8bit, 4:4:4 video format, packed into 32bit pixels.
        #// Color ordering in memory is red, green, blue, 255.
        NDIlib_FourCC_video_type_RGBX
        NDIlib_FourCC_type_RGBX

        #// Make sure this is a 32-bit enumeration.
        # NDIlib_FourCC_video_type_max

    #// FourCC values for audio frames.
    enum NDIlib_FourCC_audio_type_e:
        # // Planar 32-bit floating point. Be sure to specify the channel stride.
        NDIlib_FourCC_audio_type_FLTP
        NDIlib_FourCC_type_FLTP

        # // Make sure this is a 32-bit enumeration.
        # NDIlib_FourCC_audio_type_max

    enum NDIlib_frame_format_type_e:
        # // A progressive frame.
        NDIlib_frame_format_type_progressive

        # // A fielded frame with the field 0 being on the even lines and field 1 being
        # // on the odd lines.
        NDIlib_frame_format_type_interleaved

        # // Individual fields.
        NDIlib_frame_format_type_field_0
        NDIlib_frame_format_type_field_1

        # // Make sure this is a 32-bit enumeration.
        # NDIlib_frame_format_type_max = 0x7fffffff

    cdef const int64_t NDIlib_send_timecode_synthesize
    cdef const int64_t NDIlib_recv_timestamp_undefined

    cdef struct NDIlib_source_t:
        const char* p_ndi_name
        const char* p_url_address

    #// This describes a video frame.
    cdef struct NDIlib_video_frame_v2_t:
        # // The resolution of this frame.
        int xres
        int yres

        # // What FourCC describing the type of data for this frame.
        NDIlib_FourCC_video_type_e FourCC

        # // What is the frame rate of this frame.
        # // For instance NTSC is 30000,1001 = 30000/1001 = 29.97 fps.
        int frame_rate_N
        int frame_rate_D

        # // What is the picture aspect ratio of this frame.
        # // For instance 16.0/9.0 = 1.778 is 16:9 video
        # // 0 means square pixels.
        float picture_aspect_ratio

        # // Is this a fielded frame, or is it progressive.
        NDIlib_frame_format_type_e frame_format_type

        # // The timecode of this frame in 100-nanosecond intervals.
        int64_t timecode

        # // The video data itself.
        uint8_t* p_data

        int line_stride_in_bytes

        # cdef union: #// If the FourCC is not a compressed type, then this will be the inter-line stride of the video data
        #     # // in bytes.  If the stride is 0, then it will default to sizeof(one pixel)*xres.
        #     int line_stride_in_bytes
        #
        #     # // If the FourCC is a compressed type, then this will be the size of the p_data buffer in bytes.
        #     int data_size_in_bytes

        # // Per frame metadata for this frame. This is a NULL terminated UTF8 string that should be in XML format.
        # // If you do not want any metadata then you may specify NULL here.
        const char* p_metadata# // Present in >= v2.5

        # // This is only valid when receiving a frame and is specified as a 100-nanosecond time that was the exact
        # // moment that the frame was submitted by the sending side and is generated by the SDK. If this value is
        # // NDIlib_recv_timestamp_undefined then this value is not available and is NDIlib_recv_timestamp_undefined.
        int64_t timestamp# // Present in >= v2.5

    #// This describes an audio frame.
    cdef struct NDIlib_audio_frame_v2_t:
        # // The sample-rate of this buffer.
        int sample_rate

        # // The number of audio channels.
        int no_channels

        # // The number of audio samples per channel.
        int no_samples

        # // The timecode of this frame in 100-nanosecond intervals.
        int64_t timecode

        # // The audio data.
        float* p_data

        # // The inter channel stride of the audio channels, in bytes.
        int channel_stride_in_bytes

        # // Per frame metadata for this frame. This is a NULL terminated UTF8 string that should be in XML format.
        # // If you do not want any metadata then you may specify NULL here.
        const char* p_metadata# // Present in >= v2.5

        # // This is only valid when receiving a frame and is specified as a 100-nanosecond time that was the exact
        # // moment that the frame was submitted by the sending side and is generated by the SDK. If this value is
        # // NDIlib_recv_timestamp_undefined then this value is not available and is NDIlib_recv_timestamp_undefined.
        int64_t timestamp# // Present in >= v2.5

    #// This describes an audio frame.
    cdef struct NDIlib_audio_frame_v3_t:
        # // The sample-rate of this buffer.
        int sample_rate

        # // The number of audio channels.
        int no_channels

        # // The number of audio samples per channel.
        int no_samples

        # // The timecode of this frame in 100-nanosecond intervals.
        int64_t timecode

        # // What FourCC describing the type of data for this frame.
        NDIlib_FourCC_audio_type_e FourCC

        # // The audio data.
        uint8_t* p_data

        int channel_stride_in_bytes

        # union:
        #     # // If the FourCC is not a compressed type and the audio format is planar, then this will be the
        #     # // stride in bytes for a single channel.
        #     int channel_stride_in_bytes
        #
        #     # // If the FourCC is a compressed type, then this will be the size of the p_data buffer in bytes.
        #     int data_size_in_bytes

        # // Per frame metadata for this frame. This is a NULL terminated UTF8 string that should be in XML format.
        # // If you do not want any metadata then you may specify NULL here.
        const char* p_metadata

        # // This is only valid when receiving a frame and is specified as a 100-nanosecond time that was the exact
        # // moment that the frame was submitted by the sending side and is generated by the SDK. If this value is
        # // NDIlib_recv_timestamp_undefined then this value is not available and is NDIlib_recv_timestamp_undefined.
        int64_t timestamp

    #// The data description for metadata.
    cdef struct NDIlib_metadata_frame_t:
        # // The length of the string in UTF8 characters. This includes the NULL terminating character. If this is
        # // 0, then the length is assume to be the length of a NULL terminated string.
        int length

        # // The timecode of this frame in 100-nanosecond intervals.
        int64_t timecode

        # // The metadata as a UTF8 XML string. This is a NULL terminated string.
        char* p_data

    #// Tally structures
    cdef struct NDIlib_tally_t:
        # // Is this currently on program output.
        bint on_program

        # // Is this currently on preview output.
        bint on_preview

cdef double ndi_time_to_posix(int64_t ndi_ts) nogil except *
cdef int64_t posix_time_to_ndi(double ts) nogil except *

cpdef enum FrameType:
    unknown = NDIlib_frame_type_none
    video = NDIlib_frame_type_video
    audio = NDIlib_frame_type_audio
    metadata = NDIlib_frame_type_metadata
    error = NDIlib_frame_type_error

cdef inline NDIlib_frame_type_e frame_type_cast(FrameType value) nogil except *:
    return <NDIlib_frame_type_e>value
cdef inline FrameType frame_type_uncast(NDIlib_frame_type_e value) nogil except *:
    return <FrameType>value


cpdef enum FourCC:
    UYVY = NDIlib_FourCC_video_type_UYVY
    UYVA = NDIlib_FourCC_video_type_UYVA
    P216 = NDIlib_FourCC_video_type_P216
    PA16 = NDIlib_FourCC_video_type_PA16
    YV12 = NDIlib_FourCC_video_type_YV12
    I420 = NDIlib_FourCC_video_type_I420
    NV12 = NDIlib_FourCC_video_type_NV12
    BGRA = NDIlib_FourCC_video_type_BGRA
    BGRX = NDIlib_FourCC_video_type_BGRX
    RGBA = NDIlib_FourCC_video_type_RGBA
    RGBX = NDIlib_FourCC_video_type_RGBX

cdef inline NDIlib_FourCC_video_type_e fourcc_type_cast(FourCC value) nogil except *:
    return <NDIlib_FourCC_video_type_e>value
cdef inline FourCC fourcc_type_uncast(NDIlib_FourCC_video_type_e value) nogil except *:
    return <FourCC>value

cdef struct FourCCPackInfo:
    size_t xres
    size_t yres
    FourCC fourcc
    size_t num_planes
    size_t total_size
    size_t[4] line_strides
    size_t[4] stride_offsets

cdef FourCCPackInfo* fourcc_pack_info_create() nogil except *
cdef void fourcc_pack_info_destroy(FourCCPackInfo* p) nogil except *
cdef FourCCPackInfo* get_fourcc_pack_info(FourCC fourcc, size_t xres, size_t yres) nogil except *
cdef void calc_fourcc_pack_info(FourCCPackInfo* p) nogil except *

cpdef enum FrameFormat:
    progressive = NDIlib_frame_format_type_progressive
    interleaved = NDIlib_frame_format_type_interleaved
    field_0 = NDIlib_frame_format_type_field_0
    field_1 = NDIlib_frame_format_type_field_1

cdef inline NDIlib_frame_format_type_e frame_format_cast(FrameFormat value) nogil except *:
    return <NDIlib_frame_format_type_e>value
cdef inline FrameFormat frame_format_uncast(NDIlib_frame_format_type_e value) nogil except *:
    return <FrameFormat>value

cdef NDIlib_source_t* source_create() nogil except *
cdef void source_destroy(NDIlib_source_t* p) nogil except *


cdef NDIlib_video_frame_v2_t* video_frame_create() nogil except *
cdef NDIlib_video_frame_v2_t* video_frame_create_default() nogil except *
cdef void video_frame_destroy(NDIlib_video_frame_v2_t* p) nogil except *


cdef NDIlib_audio_frame_v3_t* audio_frame_create() nogil except *
cdef NDIlib_audio_frame_v3_t* audio_frame_create_default() nogil except *
cdef void audio_frame_destroy(NDIlib_audio_frame_v3_t* p) nogil except *

cdef NDIlib_metadata_frame_t* metadata_frame_create() nogil except *
cdef void metadata_frame_destroy(NDIlib_metadata_frame_t* p) nogil except *
