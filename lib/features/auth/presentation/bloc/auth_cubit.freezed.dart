// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AuthState {
  bool get isLogin => throw _privateConstructorUsedError;
  bool get isPasswordObscured => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(bool isLogin, bool isPasswordObscured) initial,
    required TResult Function(bool isLogin, bool isPasswordObscured) loading,
    required TResult Function(bool isLogin, bool isPasswordObscured) success,
    required TResult Function(
      bool isLogin,
      bool isPasswordObscured,
      String message,
    )
    error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(bool isLogin, bool isPasswordObscured)? initial,
    TResult? Function(bool isLogin, bool isPasswordObscured)? loading,
    TResult? Function(bool isLogin, bool isPasswordObscured)? success,
    TResult? Function(bool isLogin, bool isPasswordObscured, String message)?
    error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(bool isLogin, bool isPasswordObscured)? initial,
    TResult Function(bool isLogin, bool isPasswordObscured)? loading,
    TResult Function(bool isLogin, bool isPasswordObscured)? success,
    TResult Function(bool isLogin, bool isPasswordObscured, String message)?
    error,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Success value) success,
    required TResult Function(_Error value) error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Success value)? success,
    TResult? Function(_Error value)? error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Success value)? success,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;

  /// Create a copy of AuthState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AuthStateCopyWith<AuthState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AuthStateCopyWith<$Res> {
  factory $AuthStateCopyWith(AuthState value, $Res Function(AuthState) then) =
      _$AuthStateCopyWithImpl<$Res, AuthState>;
  @useResult
  $Res call({bool isLogin, bool isPasswordObscured});
}

/// @nodoc
class _$AuthStateCopyWithImpl<$Res, $Val extends AuthState>
    implements $AuthStateCopyWith<$Res> {
  _$AuthStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AuthState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? isLogin = null, Object? isPasswordObscured = null}) {
    return _then(
      _value.copyWith(
            isLogin: null == isLogin
                ? _value.isLogin
                : isLogin // ignore: cast_nullable_to_non_nullable
                      as bool,
            isPasswordObscured: null == isPasswordObscured
                ? _value.isPasswordObscured
                : isPasswordObscured // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$InitialImplCopyWith<$Res>
    implements $AuthStateCopyWith<$Res> {
  factory _$$InitialImplCopyWith(
    _$InitialImpl value,
    $Res Function(_$InitialImpl) then,
  ) = __$$InitialImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool isLogin, bool isPasswordObscured});
}

/// @nodoc
class __$$InitialImplCopyWithImpl<$Res>
    extends _$AuthStateCopyWithImpl<$Res, _$InitialImpl>
    implements _$$InitialImplCopyWith<$Res> {
  __$$InitialImplCopyWithImpl(
    _$InitialImpl _value,
    $Res Function(_$InitialImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AuthState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? isLogin = null, Object? isPasswordObscured = null}) {
    return _then(
      _$InitialImpl(
        isLogin: null == isLogin
            ? _value.isLogin
            : isLogin // ignore: cast_nullable_to_non_nullable
                  as bool,
        isPasswordObscured: null == isPasswordObscured
            ? _value.isPasswordObscured
            : isPasswordObscured // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$InitialImpl implements _Initial {
  const _$InitialImpl({
    required this.isLogin,
    required this.isPasswordObscured,
  });

  @override
  final bool isLogin;
  @override
  final bool isPasswordObscured;

  @override
  String toString() {
    return 'AuthState.initial(isLogin: $isLogin, isPasswordObscured: $isPasswordObscured)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InitialImpl &&
            (identical(other.isLogin, isLogin) || other.isLogin == isLogin) &&
            (identical(other.isPasswordObscured, isPasswordObscured) ||
                other.isPasswordObscured == isPasswordObscured));
  }

  @override
  int get hashCode => Object.hash(runtimeType, isLogin, isPasswordObscured);

  /// Create a copy of AuthState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InitialImplCopyWith<_$InitialImpl> get copyWith =>
      __$$InitialImplCopyWithImpl<_$InitialImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(bool isLogin, bool isPasswordObscured) initial,
    required TResult Function(bool isLogin, bool isPasswordObscured) loading,
    required TResult Function(bool isLogin, bool isPasswordObscured) success,
    required TResult Function(
      bool isLogin,
      bool isPasswordObscured,
      String message,
    )
    error,
  }) {
    return initial(isLogin, isPasswordObscured);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(bool isLogin, bool isPasswordObscured)? initial,
    TResult? Function(bool isLogin, bool isPasswordObscured)? loading,
    TResult? Function(bool isLogin, bool isPasswordObscured)? success,
    TResult? Function(bool isLogin, bool isPasswordObscured, String message)?
    error,
  }) {
    return initial?.call(isLogin, isPasswordObscured);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(bool isLogin, bool isPasswordObscured)? initial,
    TResult Function(bool isLogin, bool isPasswordObscured)? loading,
    TResult Function(bool isLogin, bool isPasswordObscured)? success,
    TResult Function(bool isLogin, bool isPasswordObscured, String message)?
    error,
    required TResult orElse(),
  }) {
    if (initial != null) {
      return initial(isLogin, isPasswordObscured);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Success value) success,
    required TResult Function(_Error value) error,
  }) {
    return initial(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Success value)? success,
    TResult? Function(_Error value)? error,
  }) {
    return initial?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Success value)? success,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) {
    if (initial != null) {
      return initial(this);
    }
    return orElse();
  }
}

abstract class _Initial implements AuthState {
  const factory _Initial({
    required final bool isLogin,
    required final bool isPasswordObscured,
  }) = _$InitialImpl;

  @override
  bool get isLogin;
  @override
  bool get isPasswordObscured;

  /// Create a copy of AuthState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InitialImplCopyWith<_$InitialImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$LoadingImplCopyWith<$Res>
    implements $AuthStateCopyWith<$Res> {
  factory _$$LoadingImplCopyWith(
    _$LoadingImpl value,
    $Res Function(_$LoadingImpl) then,
  ) = __$$LoadingImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool isLogin, bool isPasswordObscured});
}

/// @nodoc
class __$$LoadingImplCopyWithImpl<$Res>
    extends _$AuthStateCopyWithImpl<$Res, _$LoadingImpl>
    implements _$$LoadingImplCopyWith<$Res> {
  __$$LoadingImplCopyWithImpl(
    _$LoadingImpl _value,
    $Res Function(_$LoadingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AuthState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? isLogin = null, Object? isPasswordObscured = null}) {
    return _then(
      _$LoadingImpl(
        isLogin: null == isLogin
            ? _value.isLogin
            : isLogin // ignore: cast_nullable_to_non_nullable
                  as bool,
        isPasswordObscured: null == isPasswordObscured
            ? _value.isPasswordObscured
            : isPasswordObscured // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$LoadingImpl implements _Loading {
  const _$LoadingImpl({
    required this.isLogin,
    required this.isPasswordObscured,
  });

  @override
  final bool isLogin;
  @override
  final bool isPasswordObscured;

  @override
  String toString() {
    return 'AuthState.loading(isLogin: $isLogin, isPasswordObscured: $isPasswordObscured)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LoadingImpl &&
            (identical(other.isLogin, isLogin) || other.isLogin == isLogin) &&
            (identical(other.isPasswordObscured, isPasswordObscured) ||
                other.isPasswordObscured == isPasswordObscured));
  }

  @override
  int get hashCode => Object.hash(runtimeType, isLogin, isPasswordObscured);

  /// Create a copy of AuthState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LoadingImplCopyWith<_$LoadingImpl> get copyWith =>
      __$$LoadingImplCopyWithImpl<_$LoadingImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(bool isLogin, bool isPasswordObscured) initial,
    required TResult Function(bool isLogin, bool isPasswordObscured) loading,
    required TResult Function(bool isLogin, bool isPasswordObscured) success,
    required TResult Function(
      bool isLogin,
      bool isPasswordObscured,
      String message,
    )
    error,
  }) {
    return loading(isLogin, isPasswordObscured);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(bool isLogin, bool isPasswordObscured)? initial,
    TResult? Function(bool isLogin, bool isPasswordObscured)? loading,
    TResult? Function(bool isLogin, bool isPasswordObscured)? success,
    TResult? Function(bool isLogin, bool isPasswordObscured, String message)?
    error,
  }) {
    return loading?.call(isLogin, isPasswordObscured);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(bool isLogin, bool isPasswordObscured)? initial,
    TResult Function(bool isLogin, bool isPasswordObscured)? loading,
    TResult Function(bool isLogin, bool isPasswordObscured)? success,
    TResult Function(bool isLogin, bool isPasswordObscured, String message)?
    error,
    required TResult orElse(),
  }) {
    if (loading != null) {
      return loading(isLogin, isPasswordObscured);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Success value) success,
    required TResult Function(_Error value) error,
  }) {
    return loading(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Success value)? success,
    TResult? Function(_Error value)? error,
  }) {
    return loading?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Success value)? success,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) {
    if (loading != null) {
      return loading(this);
    }
    return orElse();
  }
}

abstract class _Loading implements AuthState {
  const factory _Loading({
    required final bool isLogin,
    required final bool isPasswordObscured,
  }) = _$LoadingImpl;

  @override
  bool get isLogin;
  @override
  bool get isPasswordObscured;

  /// Create a copy of AuthState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LoadingImplCopyWith<_$LoadingImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SuccessImplCopyWith<$Res>
    implements $AuthStateCopyWith<$Res> {
  factory _$$SuccessImplCopyWith(
    _$SuccessImpl value,
    $Res Function(_$SuccessImpl) then,
  ) = __$$SuccessImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool isLogin, bool isPasswordObscured});
}

/// @nodoc
class __$$SuccessImplCopyWithImpl<$Res>
    extends _$AuthStateCopyWithImpl<$Res, _$SuccessImpl>
    implements _$$SuccessImplCopyWith<$Res> {
  __$$SuccessImplCopyWithImpl(
    _$SuccessImpl _value,
    $Res Function(_$SuccessImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AuthState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? isLogin = null, Object? isPasswordObscured = null}) {
    return _then(
      _$SuccessImpl(
        isLogin: null == isLogin
            ? _value.isLogin
            : isLogin // ignore: cast_nullable_to_non_nullable
                  as bool,
        isPasswordObscured: null == isPasswordObscured
            ? _value.isPasswordObscured
            : isPasswordObscured // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$SuccessImpl implements _Success {
  const _$SuccessImpl({
    required this.isLogin,
    required this.isPasswordObscured,
  });

  @override
  final bool isLogin;
  @override
  final bool isPasswordObscured;

  @override
  String toString() {
    return 'AuthState.success(isLogin: $isLogin, isPasswordObscured: $isPasswordObscured)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SuccessImpl &&
            (identical(other.isLogin, isLogin) || other.isLogin == isLogin) &&
            (identical(other.isPasswordObscured, isPasswordObscured) ||
                other.isPasswordObscured == isPasswordObscured));
  }

  @override
  int get hashCode => Object.hash(runtimeType, isLogin, isPasswordObscured);

  /// Create a copy of AuthState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SuccessImplCopyWith<_$SuccessImpl> get copyWith =>
      __$$SuccessImplCopyWithImpl<_$SuccessImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(bool isLogin, bool isPasswordObscured) initial,
    required TResult Function(bool isLogin, bool isPasswordObscured) loading,
    required TResult Function(bool isLogin, bool isPasswordObscured) success,
    required TResult Function(
      bool isLogin,
      bool isPasswordObscured,
      String message,
    )
    error,
  }) {
    return success(isLogin, isPasswordObscured);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(bool isLogin, bool isPasswordObscured)? initial,
    TResult? Function(bool isLogin, bool isPasswordObscured)? loading,
    TResult? Function(bool isLogin, bool isPasswordObscured)? success,
    TResult? Function(bool isLogin, bool isPasswordObscured, String message)?
    error,
  }) {
    return success?.call(isLogin, isPasswordObscured);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(bool isLogin, bool isPasswordObscured)? initial,
    TResult Function(bool isLogin, bool isPasswordObscured)? loading,
    TResult Function(bool isLogin, bool isPasswordObscured)? success,
    TResult Function(bool isLogin, bool isPasswordObscured, String message)?
    error,
    required TResult orElse(),
  }) {
    if (success != null) {
      return success(isLogin, isPasswordObscured);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Success value) success,
    required TResult Function(_Error value) error,
  }) {
    return success(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Success value)? success,
    TResult? Function(_Error value)? error,
  }) {
    return success?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Success value)? success,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) {
    if (success != null) {
      return success(this);
    }
    return orElse();
  }
}

abstract class _Success implements AuthState {
  const factory _Success({
    required final bool isLogin,
    required final bool isPasswordObscured,
  }) = _$SuccessImpl;

  @override
  bool get isLogin;
  @override
  bool get isPasswordObscured;

  /// Create a copy of AuthState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SuccessImplCopyWith<_$SuccessImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ErrorImplCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory _$$ErrorImplCopyWith(
    _$ErrorImpl value,
    $Res Function(_$ErrorImpl) then,
  ) = __$$ErrorImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool isLogin, bool isPasswordObscured, String message});
}

/// @nodoc
class __$$ErrorImplCopyWithImpl<$Res>
    extends _$AuthStateCopyWithImpl<$Res, _$ErrorImpl>
    implements _$$ErrorImplCopyWith<$Res> {
  __$$ErrorImplCopyWithImpl(
    _$ErrorImpl _value,
    $Res Function(_$ErrorImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AuthState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isLogin = null,
    Object? isPasswordObscured = null,
    Object? message = null,
  }) {
    return _then(
      _$ErrorImpl(
        isLogin: null == isLogin
            ? _value.isLogin
            : isLogin // ignore: cast_nullable_to_non_nullable
                  as bool,
        isPasswordObscured: null == isPasswordObscured
            ? _value.isPasswordObscured
            : isPasswordObscured // ignore: cast_nullable_to_non_nullable
                  as bool,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$ErrorImpl implements _Error {
  const _$ErrorImpl({
    required this.isLogin,
    required this.isPasswordObscured,
    required this.message,
  });

  @override
  final bool isLogin;
  @override
  final bool isPasswordObscured;
  @override
  final String message;

  @override
  String toString() {
    return 'AuthState.error(isLogin: $isLogin, isPasswordObscured: $isPasswordObscured, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ErrorImpl &&
            (identical(other.isLogin, isLogin) || other.isLogin == isLogin) &&
            (identical(other.isPasswordObscured, isPasswordObscured) ||
                other.isPasswordObscured == isPasswordObscured) &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, isLogin, isPasswordObscured, message);

  /// Create a copy of AuthState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ErrorImplCopyWith<_$ErrorImpl> get copyWith =>
      __$$ErrorImplCopyWithImpl<_$ErrorImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(bool isLogin, bool isPasswordObscured) initial,
    required TResult Function(bool isLogin, bool isPasswordObscured) loading,
    required TResult Function(bool isLogin, bool isPasswordObscured) success,
    required TResult Function(
      bool isLogin,
      bool isPasswordObscured,
      String message,
    )
    error,
  }) {
    return error(isLogin, isPasswordObscured, message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(bool isLogin, bool isPasswordObscured)? initial,
    TResult? Function(bool isLogin, bool isPasswordObscured)? loading,
    TResult? Function(bool isLogin, bool isPasswordObscured)? success,
    TResult? Function(bool isLogin, bool isPasswordObscured, String message)?
    error,
  }) {
    return error?.call(isLogin, isPasswordObscured, message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(bool isLogin, bool isPasswordObscured)? initial,
    TResult Function(bool isLogin, bool isPasswordObscured)? loading,
    TResult Function(bool isLogin, bool isPasswordObscured)? success,
    TResult Function(bool isLogin, bool isPasswordObscured, String message)?
    error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(isLogin, isPasswordObscured, message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Success value) success,
    required TResult Function(_Error value) error,
  }) {
    return error(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Success value)? success,
    TResult? Function(_Error value)? error,
  }) {
    return error?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Success value)? success,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(this);
    }
    return orElse();
  }
}

abstract class _Error implements AuthState {
  const factory _Error({
    required final bool isLogin,
    required final bool isPasswordObscured,
    required final String message,
  }) = _$ErrorImpl;

  @override
  bool get isLogin;
  @override
  bool get isPasswordObscured;
  String get message;

  /// Create a copy of AuthState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ErrorImplCopyWith<_$ErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
