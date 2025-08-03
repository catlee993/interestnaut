// This is a generated file - do not edit.
//
// Generated from recommendation.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use recommendationRequestDescriptor instead')
const RecommendationRequest$json = {
  '1': 'RecommendationRequest',
  '2': [
    {'1': 'media_type', '3': 1, '4': 1, '5': 9, '10': 'mediaType'},
    {'1': 'user_query', '3': 2, '4': 1, '5': 9, '10': 'userQuery'},
    {'1': 'liked_media_ids', '3': 3, '4': 3, '5': 9, '10': 'likedMediaIds'},
    {
      '1': 'favorited_media_ids',
      '3': 4,
      '4': 3,
      '5': 9,
      '10': 'favoritedMediaIds'
    },
    {
      '1': 'watchlist_media_ids',
      '3': 5,
      '4': 3,
      '5': 9,
      '10': 'watchlistMediaIds'
    },
    {
      '1': 'disliked_media_ids',
      '3': 6,
      '4': 3,
      '5': 9,
      '10': 'dislikedMediaIds'
    },
    {'1': 'skipped_media_ids', '3': 7, '4': 3, '5': 9, '10': 'skippedMediaIds'},
    {'1': 'exclude_media_ids', '3': 8, '4': 3, '5': 9, '10': 'excludeMediaIds'},
    {'1': 'constraints', '3': 9, '4': 3, '5': 9, '10': 'constraints'},
    {'1': 'limit', '3': 10, '4': 1, '5': 5, '10': 'limit'},
    {
      '1': 'use_behavioral_matching',
      '3': 11,
      '4': 1,
      '5': 8,
      '10': 'useBehavioralMatching'
    },
    {
      '1': 'similarity_threshold',
      '3': 12,
      '4': 1,
      '5': 1,
      '10': 'similarityThreshold'
    },
    {
      '1': 'attributes_to_match',
      '3': 13,
      '4': 1,
      '5': 5,
      '10': 'attributesToMatch'
    },
    {
      '1': 'priority_title_ids',
      '3': 14,
      '4': 3,
      '5': 9,
      '10': 'priorityTitleIds'
    },
  ],
};

/// Descriptor for `RecommendationRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recommendationRequestDescriptor = $convert.base64Decode(
    'ChVSZWNvbW1lbmRhdGlvblJlcXVlc3QSHQoKbWVkaWFfdHlwZRgBIAEoCVIJbWVkaWFUeXBlEh'
    '0KCnVzZXJfcXVlcnkYAiABKAlSCXVzZXJRdWVyeRImCg9saWtlZF9tZWRpYV9pZHMYAyADKAlS'
    'DWxpa2VkTWVkaWFJZHMSLgoTZmF2b3JpdGVkX21lZGlhX2lkcxgEIAMoCVIRZmF2b3JpdGVkTW'
    'VkaWFJZHMSLgoTd2F0Y2hsaXN0X21lZGlhX2lkcxgFIAMoCVIRd2F0Y2hsaXN0TWVkaWFJZHMS'
    'LAoSZGlzbGlrZWRfbWVkaWFfaWRzGAYgAygJUhBkaXNsaWtlZE1lZGlhSWRzEioKEXNraXBwZW'
    'RfbWVkaWFfaWRzGAcgAygJUg9za2lwcGVkTWVkaWFJZHMSKgoRZXhjbHVkZV9tZWRpYV9pZHMY'
    'CCADKAlSD2V4Y2x1ZGVNZWRpYUlkcxIgCgtjb25zdHJhaW50cxgJIAMoCVILY29uc3RyYWludH'
    'MSFAoFbGltaXQYCiABKAVSBWxpbWl0EjYKF3VzZV9iZWhhdmlvcmFsX21hdGNoaW5nGAsgASgI'
    'UhV1c2VCZWhhdmlvcmFsTWF0Y2hpbmcSMQoUc2ltaWxhcml0eV90aHJlc2hvbGQYDCABKAFSE3'
    'NpbWlsYXJpdHlUaHJlc2hvbGQSLgoTYXR0cmlidXRlc190b19tYXRjaBgNIAEoBVIRYXR0cmli'
    'dXRlc1RvTWF0Y2gSLAoScHJpb3JpdHlfdGl0bGVfaWRzGA4gAygJUhBwcmlvcml0eVRpdGxlSW'
    'Rz');

@$core.Deprecated('Use recommendationResponseDescriptor instead')
const RecommendationResponse$json = {
  '1': 'RecommendationResponse',
  '2': [
    {
      '1': 'recommendations',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.recommendation.MediaItem',
      '10': 'recommendations'
    },
    {'1': 'error', '3': 2, '4': 1, '5': 9, '10': 'error'},
    {
      '1': 'metadata',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.recommendation.RecommendationMetadata',
      '10': 'metadata'
    },
  ],
};

/// Descriptor for `RecommendationResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recommendationResponseDescriptor = $convert.base64Decode(
    'ChZSZWNvbW1lbmRhdGlvblJlc3BvbnNlEkMKD3JlY29tbWVuZGF0aW9ucxgBIAMoCzIZLnJlY2'
    '9tbWVuZGF0aW9uLk1lZGlhSXRlbVIPcmVjb21tZW5kYXRpb25zEhQKBWVycm9yGAIgASgJUgVl'
    'cnJvchJCCghtZXRhZGF0YRgDIAEoCzImLnJlY29tbWVuZGF0aW9uLlJlY29tbWVuZGF0aW9uTW'
    'V0YWRhdGFSCG1ldGFkYXRh');

@$core.Deprecated('Use recommendationMetadataDescriptor instead')
const RecommendationMetadata$json = {
  '1': 'RecommendationMetadata',
  '2': [
    {'1': 'algorithm_used', '3': 1, '4': 1, '5': 9, '10': 'algorithmUsed'},
    {'1': 'total_candidates', '3': 2, '4': 1, '5': 5, '10': 'totalCandidates'},
    {
      '1': 'processing_time_ms',
      '3': 3,
      '4': 1,
      '5': 1,
      '10': 'processingTimeMs'
    },
  ],
};

/// Descriptor for `RecommendationMetadata`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recommendationMetadataDescriptor = $convert.base64Decode(
    'ChZSZWNvbW1lbmRhdGlvbk1ldGFkYXRhEiUKDmFsZ29yaXRobV91c2VkGAEgASgJUg1hbGdvcm'
    'l0aG1Vc2VkEikKEHRvdGFsX2NhbmRpZGF0ZXMYAiABKAVSD3RvdGFsQ2FuZGlkYXRlcxIsChJw'
    'cm9jZXNzaW5nX3RpbWVfbXMYAyABKAFSEHByb2Nlc3NpbmdUaW1lTXM=');

@$core.Deprecated('Use similarItemsRequestDescriptor instead')
const SimilarItemsRequest$json = {
  '1': 'SimilarItemsRequest',
  '2': [
    {
      '1': 'reference_media_id',
      '3': 1,
      '4': 1,
      '5': 9,
      '10': 'referenceMediaId'
    },
    {'1': 'media_type', '3': 2, '4': 1, '5': 9, '10': 'mediaType'},
    {'1': 'exclude_media_ids', '3': 3, '4': 3, '5': 9, '10': 'excludeMediaIds'},
    {'1': 'limit', '3': 4, '4': 1, '5': 5, '10': 'limit'},
  ],
};

/// Descriptor for `SimilarItemsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List similarItemsRequestDescriptor = $convert.base64Decode(
    'ChNTaW1pbGFySXRlbXNSZXF1ZXN0EiwKEnJlZmVyZW5jZV9tZWRpYV9pZBgBIAEoCVIQcmVmZX'
    'JlbmNlTWVkaWFJZBIdCgptZWRpYV90eXBlGAIgASgJUgltZWRpYVR5cGUSKgoRZXhjbHVkZV9t'
    'ZWRpYV9pZHMYAyADKAlSD2V4Y2x1ZGVNZWRpYUlkcxIUCgVsaW1pdBgEIAEoBVIFbGltaXQ=');

@$core.Deprecated('Use similarItemsResponseDescriptor instead')
const SimilarItemsResponse$json = {
  '1': 'SimilarItemsResponse',
  '2': [
    {
      '1': 'similar_items',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.recommendation.MediaItem',
      '10': 'similarItems'
    },
    {'1': 'error', '3': 2, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `SimilarItemsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List similarItemsResponseDescriptor = $convert.base64Decode(
    'ChRTaW1pbGFySXRlbXNSZXNwb25zZRI+Cg1zaW1pbGFyX2l0ZW1zGAEgAygLMhkucmVjb21tZW'
    '5kYXRpb24uTWVkaWFJdGVtUgxzaW1pbGFySXRlbXMSFAoFZXJyb3IYAiABKAlSBWVycm9y');

@$core.Deprecated('Use searchRequestDescriptor instead')
const SearchRequest$json = {
  '1': 'SearchRequest',
  '2': [
    {'1': 'media_type', '3': 1, '4': 1, '5': 9, '10': 'mediaType'},
    {'1': 'constraints', '3': 2, '4': 3, '5': 9, '10': 'constraints'},
    {'1': 'exclude_media_ids', '3': 3, '4': 3, '5': 9, '10': 'excludeMediaIds'},
    {'1': 'limit', '3': 4, '4': 1, '5': 5, '10': 'limit'},
    {'1': 'offset', '3': 5, '4': 1, '5': 5, '10': 'offset'},
  ],
};

/// Descriptor for `SearchRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchRequestDescriptor = $convert.base64Decode(
    'Cg1TZWFyY2hSZXF1ZXN0Eh0KCm1lZGlhX3R5cGUYASABKAlSCW1lZGlhVHlwZRIgCgtjb25zdH'
    'JhaW50cxgCIAMoCVILY29uc3RyYWludHMSKgoRZXhjbHVkZV9tZWRpYV9pZHMYAyADKAlSD2V4'
    'Y2x1ZGVNZWRpYUlkcxIUCgVsaW1pdBgEIAEoBVIFbGltaXQSFgoGb2Zmc2V0GAUgASgFUgZvZm'
    'ZzZXQ=');

@$core.Deprecated('Use searchResponseDescriptor instead')
const SearchResponse$json = {
  '1': 'SearchResponse',
  '2': [
    {
      '1': 'results',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.recommendation.MediaItem',
      '10': 'results'
    },
    {'1': 'error', '3': 2, '4': 1, '5': 9, '10': 'error'},
    {'1': 'total_count', '3': 3, '4': 1, '5': 5, '10': 'totalCount'},
  ],
};

/// Descriptor for `SearchResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchResponseDescriptor = $convert.base64Decode(
    'Cg5TZWFyY2hSZXNwb25zZRIzCgdyZXN1bHRzGAEgAygLMhkucmVjb21tZW5kYXRpb24uTWVkaW'
    'FJdGVtUgdyZXN1bHRzEhQKBWVycm9yGAIgASgJUgVlcnJvchIfCgt0b3RhbF9jb3VudBgDIAEo'
    'BVIKdG90YWxDb3VudA==');

@$core.Deprecated('Use mediaDetailsRequestDescriptor instead')
const MediaDetailsRequest$json = {
  '1': 'MediaDetailsRequest',
  '2': [
    {'1': 'media_id', '3': 1, '4': 1, '5': 9, '10': 'mediaId'},
    {'1': 'media_type', '3': 2, '4': 1, '5': 9, '10': 'mediaType'},
  ],
};

/// Descriptor for `MediaDetailsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mediaDetailsRequestDescriptor = $convert.base64Decode(
    'ChNNZWRpYURldGFpbHNSZXF1ZXN0EhkKCG1lZGlhX2lkGAEgASgJUgdtZWRpYUlkEh0KCm1lZG'
    'lhX3R5cGUYAiABKAlSCW1lZGlhVHlwZQ==');

@$core.Deprecated('Use mediaDetailsResponseDescriptor instead')
const MediaDetailsResponse$json = {
  '1': 'MediaDetailsResponse',
  '2': [
    {
      '1': 'media',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.recommendation.MediaItem',
      '10': 'media'
    },
    {'1': 'error', '3': 2, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `MediaDetailsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mediaDetailsResponseDescriptor = $convert.base64Decode(
    'ChRNZWRpYURldGFpbHNSZXNwb25zZRIvCgVtZWRpYRgBIAEoCzIZLnJlY29tbWVuZGF0aW9uLk'
    '1lZGlhSXRlbVIFbWVkaWESFAoFZXJyb3IYAiABKAlSBWVycm9y');

@$core.Deprecated('Use randomMediaRequestDescriptor instead')
const RandomMediaRequest$json = {
  '1': 'RandomMediaRequest',
  '2': [
    {'1': 'media_type', '3': 1, '4': 1, '5': 9, '10': 'mediaType'},
    {'1': 'exclude_media_ids', '3': 2, '4': 3, '5': 9, '10': 'excludeMediaIds'},
    {'1': 'limit', '3': 3, '4': 1, '5': 5, '10': 'limit'},
  ],
};

/// Descriptor for `RandomMediaRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List randomMediaRequestDescriptor = $convert.base64Decode(
    'ChJSYW5kb21NZWRpYVJlcXVlc3QSHQoKbWVkaWFfdHlwZRgBIAEoCVIJbWVkaWFUeXBlEioKEW'
    'V4Y2x1ZGVfbWVkaWFfaWRzGAIgAygJUg9leGNsdWRlTWVkaWFJZHMSFAoFbGltaXQYAyABKAVS'
    'BWxpbWl0');

@$core.Deprecated('Use randomMediaResponseDescriptor instead')
const RandomMediaResponse$json = {
  '1': 'RandomMediaResponse',
  '2': [
    {
      '1': 'items',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.recommendation.MediaItem',
      '10': 'items'
    },
    {'1': 'error', '3': 2, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `RandomMediaResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List randomMediaResponseDescriptor = $convert.base64Decode(
    'ChNSYW5kb21NZWRpYVJlc3BvbnNlEi8KBWl0ZW1zGAEgAygLMhkucmVjb21tZW5kYXRpb24uTW'
    'VkaWFJdGVtUgVpdGVtcxIUCgVlcnJvchgCIAEoCVIFZXJyb3I=');

@$core.Deprecated('Use healthCheckRequestDescriptor instead')
const HealthCheckRequest$json = {
  '1': 'HealthCheckRequest',
};

/// Descriptor for `HealthCheckRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List healthCheckRequestDescriptor =
    $convert.base64Decode('ChJIZWFsdGhDaGVja1JlcXVlc3Q=');

@$core.Deprecated('Use healthCheckResponseDescriptor instead')
const HealthCheckResponse$json = {
  '1': 'HealthCheckResponse',
  '2': [
    {'1': 'healthy', '3': 1, '4': 1, '5': 8, '10': 'healthy'},
    {'1': 'version', '3': 2, '4': 1, '5': 9, '10': 'version'},
    {
      '1': 'database_status',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.recommendation.HealthCheckResponse.DatabaseStatusEntry',
      '10': 'databaseStatus'
    },
  ],
  '3': [HealthCheckResponse_DatabaseStatusEntry$json],
};

@$core.Deprecated('Use healthCheckResponseDescriptor instead')
const HealthCheckResponse_DatabaseStatusEntry$json = {
  '1': 'DatabaseStatusEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 8, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `HealthCheckResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List healthCheckResponseDescriptor = $convert.base64Decode(
    'ChNIZWFsdGhDaGVja1Jlc3BvbnNlEhgKB2hlYWx0aHkYASABKAhSB2hlYWx0aHkSGAoHdmVyc2'
    'lvbhgCIAEoCVIHdmVyc2lvbhJgCg9kYXRhYmFzZV9zdGF0dXMYAyADKAsyNy5yZWNvbW1lbmRh'
    'dGlvbi5IZWFsdGhDaGVja1Jlc3BvbnNlLkRhdGFiYXNlU3RhdHVzRW50cnlSDmRhdGFiYXNlU3'
    'RhdHVzGkEKE0RhdGFiYXNlU3RhdHVzRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUY'
    'AiABKAhSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use availableThemesRequestDescriptor instead')
const AvailableThemesRequest$json = {
  '1': 'AvailableThemesRequest',
  '2': [
    {'1': 'media_type', '3': 1, '4': 1, '5': 9, '10': 'mediaType'},
  ],
};

/// Descriptor for `AvailableThemesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List availableThemesRequestDescriptor =
    $convert.base64Decode(
        'ChZBdmFpbGFibGVUaGVtZXNSZXF1ZXN0Eh0KCm1lZGlhX3R5cGUYASABKAlSCW1lZGlhVHlwZQ'
        '==');

@$core.Deprecated('Use availableThemesResponseDescriptor instead')
const AvailableThemesResponse$json = {
  '1': 'AvailableThemesResponse',
  '2': [
    {'1': 'themes', '3': 1, '4': 3, '5': 9, '10': 'themes'},
    {'1': 'error', '3': 2, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `AvailableThemesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List availableThemesResponseDescriptor =
    $convert.base64Decode(
        'ChdBdmFpbGFibGVUaGVtZXNSZXNwb25zZRIWCgZ0aGVtZXMYASADKAlSBnRoZW1lcxIUCgVlcn'
        'JvchgCIAEoCVIFZXJyb3I=');

@$core.Deprecated('Use availableGenresRequestDescriptor instead')
const AvailableGenresRequest$json = {
  '1': 'AvailableGenresRequest',
  '2': [
    {'1': 'media_type', '3': 1, '4': 1, '5': 9, '10': 'mediaType'},
  ],
};

/// Descriptor for `AvailableGenresRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List availableGenresRequestDescriptor =
    $convert.base64Decode(
        'ChZBdmFpbGFibGVHZW5yZXNSZXF1ZXN0Eh0KCm1lZGlhX3R5cGUYASABKAlSCW1lZGlhVHlwZQ'
        '==');

@$core.Deprecated('Use availableGenresResponseDescriptor instead')
const AvailableGenresResponse$json = {
  '1': 'AvailableGenresResponse',
  '2': [
    {'1': 'genres', '3': 1, '4': 3, '5': 9, '10': 'genres'},
    {'1': 'error', '3': 2, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `AvailableGenresResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List availableGenresResponseDescriptor =
    $convert.base64Decode(
        'ChdBdmFpbGFibGVHZW5yZXNSZXNwb25zZRIWCgZnZW5yZXMYASADKAlSBmdlbnJlcxIUCgVlcn'
        'JvchgCIAEoCVIFZXJyb3I=');

@$core.Deprecated('Use searchThemesRequestDescriptor instead')
const SearchThemesRequest$json = {
  '1': 'SearchThemesRequest',
  '2': [
    {'1': 'media_type', '3': 1, '4': 1, '5': 9, '10': 'mediaType'},
    {'1': 'query', '3': 2, '4': 1, '5': 9, '10': 'query'},
    {'1': 'limit', '3': 3, '4': 1, '5': 5, '10': 'limit'},
  ],
};

/// Descriptor for `SearchThemesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchThemesRequestDescriptor = $convert.base64Decode(
    'ChNTZWFyY2hUaGVtZXNSZXF1ZXN0Eh0KCm1lZGlhX3R5cGUYASABKAlSCW1lZGlhVHlwZRIUCg'
    'VxdWVyeRgCIAEoCVIFcXVlcnkSFAoFbGltaXQYAyABKAVSBWxpbWl0');

@$core.Deprecated('Use searchThemesResponseDescriptor instead')
const SearchThemesResponse$json = {
  '1': 'SearchThemesResponse',
  '2': [
    {'1': 'themes', '3': 1, '4': 3, '5': 9, '10': 'themes'},
    {'1': 'total_count', '3': 2, '4': 1, '5': 5, '10': 'totalCount'},
    {'1': 'error', '3': 3, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `SearchThemesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchThemesResponseDescriptor = $convert.base64Decode(
    'ChRTZWFyY2hUaGVtZXNSZXNwb25zZRIWCgZ0aGVtZXMYASADKAlSBnRoZW1lcxIfCgt0b3RhbF'
    '9jb3VudBgCIAEoBVIKdG90YWxDb3VudBIUCgVlcnJvchgDIAEoCVIFZXJyb3I=');

@$core.Deprecated('Use searchGenresRequestDescriptor instead')
const SearchGenresRequest$json = {
  '1': 'SearchGenresRequest',
  '2': [
    {'1': 'media_type', '3': 1, '4': 1, '5': 9, '10': 'mediaType'},
    {'1': 'query', '3': 2, '4': 1, '5': 9, '10': 'query'},
    {'1': 'limit', '3': 3, '4': 1, '5': 5, '10': 'limit'},
  ],
};

/// Descriptor for `SearchGenresRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchGenresRequestDescriptor = $convert.base64Decode(
    'ChNTZWFyY2hHZW5yZXNSZXF1ZXN0Eh0KCm1lZGlhX3R5cGUYASABKAlSCW1lZGlhVHlwZRIUCg'
    'VxdWVyeRgCIAEoCVIFcXVlcnkSFAoFbGltaXQYAyABKAVSBWxpbWl0');

@$core.Deprecated('Use searchGenresResponseDescriptor instead')
const SearchGenresResponse$json = {
  '1': 'SearchGenresResponse',
  '2': [
    {'1': 'genres', '3': 1, '4': 3, '5': 9, '10': 'genres'},
    {'1': 'total_count', '3': 2, '4': 1, '5': 5, '10': 'totalCount'},
    {'1': 'error', '3': 3, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `SearchGenresResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchGenresResponseDescriptor = $convert.base64Decode(
    'ChRTZWFyY2hHZW5yZXNSZXNwb25zZRIWCgZnZW5yZXMYASADKAlSBmdlbnJlcxIfCgt0b3RhbF'
    '9jb3VudBgCIAEoBVIKdG90YWxDb3VudBIUCgVlcnJvchgDIAEoCVIFZXJyb3I=');

@$core.Deprecated('Use mediaItemDescriptor instead')
const MediaItem$json = {
  '1': 'MediaItem',
  '2': [
    {'1': 'media_id', '3': 1, '4': 1, '5': 9, '10': 'mediaId'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'primary_creator', '3': 3, '4': 1, '5': 9, '10': 'primaryCreator'},
    {'1': 'media_type', '3': 4, '4': 1, '5': 9, '10': 'mediaType'},
    {'1': 'album', '3': 5, '4': 1, '5': 9, '10': 'album'},
    {'1': 'cover_art_url', '3': 6, '4': 1, '5': 9, '10': 'coverArtUrl'},
    {'1': 'description', '3': 7, '4': 1, '5': 9, '10': 'description'},
    {'1': 'wiki_url', '3': 8, '4': 1, '5': 9, '10': 'wikiUrl'},
    {'1': 'wikidata_id', '3': 9, '4': 1, '5': 9, '10': 'wikidataId'},
    {'1': 'themes', '3': 10, '4': 1, '5': 9, '10': 'themes'},
    {'1': 'similarity_score', '3': 11, '4': 1, '5': 1, '10': 'similarityScore'},
    {'1': 'reasoning', '3': 12, '4': 1, '5': 9, '10': 'reasoning'},
    {'1': 'youtube_id', '3': 13, '4': 1, '5': 9, '10': 'youtubeId'},
    {'1': 'spotify_id', '3': 14, '4': 1, '5': 9, '10': 'spotifyId'},
    {'1': 'genres', '3': 15, '4': 1, '5': 9, '10': 'genres'},
  ],
};

/// Descriptor for `MediaItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mediaItemDescriptor = $convert.base64Decode(
    'CglNZWRpYUl0ZW0SGQoIbWVkaWFfaWQYASABKAlSB21lZGlhSWQSFAoFdGl0bGUYAiABKAlSBX'
    'RpdGxlEicKD3ByaW1hcnlfY3JlYXRvchgDIAEoCVIOcHJpbWFyeUNyZWF0b3ISHQoKbWVkaWFf'
    'dHlwZRgEIAEoCVIJbWVkaWFUeXBlEhQKBWFsYnVtGAUgASgJUgVhbGJ1bRIiCg1jb3Zlcl9hcn'
    'RfdXJsGAYgASgJUgtjb3ZlckFydFVybBIgCgtkZXNjcmlwdGlvbhgHIAEoCVILZGVzY3JpcHRp'
    'b24SGQoId2lraV91cmwYCCABKAlSB3dpa2lVcmwSHwoLd2lraWRhdGFfaWQYCSABKAlSCndpa2'
    'lkYXRhSWQSFgoGdGhlbWVzGAogASgJUgZ0aGVtZXMSKQoQc2ltaWxhcml0eV9zY29yZRgLIAEo'
    'AVIPc2ltaWxhcml0eVNjb3JlEhwKCXJlYXNvbmluZxgMIAEoCVIJcmVhc29uaW5nEh0KCnlvdX'
    'R1YmVfaWQYDSABKAlSCXlvdXR1YmVJZBIdCgpzcG90aWZ5X2lkGA4gASgJUglzcG90aWZ5SWQS'
    'FgoGZ2VucmVzGA8gASgJUgZnZW5yZXM=');
