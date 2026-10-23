// Copyright (c) 2026, rainyl. All rights reserved. Use of this source code is governed by a
// Apache-2.0 license that can be found in the LICENSE file.

import 'dart:ffi' as ffi;

import '../g/apriltag.g.dart' as C;

/// Defines a matrix structure for holding double-precision values with
/// data in row-major order (i.e. index = row*ncols + col).
///
/// nrows and ncols are 1-based counts with the exception that a scalar (non-matrix)
///   is represented with nrows=0 and/or ncols=0.
class MatD {
  /// Number of rows in the matrix.
  final int nrows;

  /// Number of columns in the matrix.
  final int ncols;

  /// Data buffer holding the matrix values.
  final List<double> data;

  /// Creates a double matrix with the given number of rows and columns (or a scalar
  /// in the case where rows=0 and/or cols=0). All data elements will be initialized
  /// to zero. It is the caller's responsibility to call matd_destroy() on the
  /// returned matrix.
  MatD(this.nrows, this.ncols, {List<double>? data})
    : data = data ?? List<double>.filled(nrows * ncols, 0.0, growable: false);

  /// Creates a scalar with the supplied value 'v'. It is the caller's responsibility
  /// to call matd_destroy() on the returned matrix.
  ///
  /// NOTE: Scalars are different than 1x1 matrices (implementation note:
  /// they are encoded as 0x0 matrices). For example: for matrices A*B, A
  /// and B must both have specific dimensions. However, if A is a
  /// scalar, there are no restrictions on the size of B.
  factory MatD.scalar(double value) => MatD(0, 0, data: [value]);

  /// Creates a square identity matrix with the given number of rows (and
  /// therefore columns), or a scalar with value 1 in the case where dim=0.
  /// It is the caller's responsibility to call matd_destroy() on the
  /// returned matrix.
  factory MatD.identity(int dim) {
    if (dim == 0) return MatD.scalar(1.0);
    return MatD(
      dim,
      dim,
      data: List<double>.generate(dim * dim, (i) => i % (dim + 1) == 0 ? 1.0 : 0.0, growable: false),
    );
  }

  /// Retrieves the cell value for matrix 'm' at the given zero-based row and column index.
  /// Performs more thorough validation checking than MATD_EL().
  double get(int row, int col) => data[row * ncols + col];

  /// Assigns the given value to the matrix cell at the given zero-based row and
  /// column index. Performs more thorough validation checking than MATD_EL().
  void put(int row, int col, double value) => data[row * ncols + col] = value;

  /// Determines whether the supplied matrix 'a' is a scalar (positive return) or
  /// not (zero return, indicating a matrix of dimensions at least 1x1).
  bool get isScalar => nrows == 0 && ncols == 0 && data.length == 1;

  /// Determines whether the supplied matrix 'a' is a row or column vector
  /// (positive return) or not (zero return, indicating either 'a' is a scalar or a
  /// matrix with at least one dimension > 1).
  bool get isVector => nrows == 1 || ncols == 1;

  /// Retrieves the scalar value of the given element ('m' must be a scalar).
  /// Performs more thorough validation checking than MATD_EL().
  double getSclar() {
    if (!isScalar) throw StateError('Matrix is not a scalar.');
    return data[0];
  }

  /// Assigns the given value to the supplied scalar element ('m' must be a scalar).
  /// Performs more thorough validation checking than MATD_EL().
  void putScalar(double value) {
    if (!isScalar) throw StateError('Matrix is not a scalar.');
    data[0] = value;
  }

  /// Creates an exact copy of the supplied matrix 'm'. It is the caller's
  /// responsibility to call matd_destroy() on the returned matrix.
  MatD copy() => MatD(nrows, ncols, data: List<double>.from(data, growable: false));

  /// Adds the two supplied matrices together, cell-by-cell, and returns the results
  /// as a new matrix of the same dimensions. The supplied matrices must have
  /// identical dimensions.  It is the caller's responsibility to call matd_destroy()
  /// on the returned matrix.
  MatD operator +(MatD b) {
    if (nrows != b.nrows || ncols != b.ncols) throw StateError('Matrix dimensions do not match.');
    return MatD(
      nrows,
      ncols,
      data: List<double>.generate(nrows * ncols, (i) => data[i] + b.data[i], growable: false),
    );
  }

  /// Subtracts matrix 'b' from matrix 'a', cell-by-cell, and returns the results
  /// as a new matrix of the same dimensions. The supplied matrices must have
  /// identical dimensions.  It is the caller's responsibility to call matd_destroy()
  /// on the returned matrix.
  MatD operator -(MatD b) {
    if (nrows != b.nrows || ncols != b.ncols) throw StateError('Matrix dimensions do not match.');
    return MatD(
      nrows,
      ncols,
      data: List<double>.generate(nrows * ncols, (i) => data[i] - b.data[i], growable: false),
    );
  }

  /// Multiplies the two supplied matrices together, per the standard matrix
  /// multiplication rules. The number of columns in the first matrix must
  /// equal the number of rows in the second matrix.  It is the caller's
  /// responsibility to call matd_destroy() on the returned matrix.
  MatD operator *(MatD b) {
    if (ncols != b.nrows) throw StateError('Matrix dimensions do not match.');
    return MatD(
      nrows,
      b.ncols,
      data: List<double>.generate(
        nrows * b.ncols,
        (i) => data[i ~/ b.ncols * ncols + (i % b.ncols)] * b.data[i % b.ncols * b.ncols + (i ~/ b.ncols)],
        growable: false,
      ),
    );
  }

  /// Scales all cell values of matrix 'a' by the given scale factor 's' and
  /// returns the result as a new matrix of the same dimensions. It is the caller's
  /// responsibility to call matd_destroy() on the returned matrix.
  MatD scale(double s, {bool inplace = false}) {
    if (isScalar) return MatD.scalar(s * getSclar());
    if (inplace) {
      for (int i = 0; i < nrows * ncols; i++) {
        data[i] *= s;
      }
      return this;
    }
    return MatD(
      nrows,
      ncols,
      data: List<double>.generate(nrows * ncols, (i) => s * data[i], growable: false),
    );
  }

  /// Creates a matrix which is the transpose of the supplied matrix 'a'. It is the
  /// caller's responsibility to call matd_destroy() on the returned matrix.
  MatD transpose() {
    if (isScalar) return MatD.scalar(getSclar());
    return MatD(
      ncols,
      nrows,
      data: List<double>.generate(
        nrows * ncols,
        (i) => data[i % nrows * ncols + (i ~/ nrows)],
        growable: false,
      ),
    );
  }

  ffi.Pointer<C.matd_t> get toNative {
    final ptr = C.matd_create(nrows, ncols);
    ptr.ref.data.asTypedList(nrows * ncols).setAll(0, data);
    return ptr;
  }
}

extension MatDPointerExtension on ffi.Pointer<C.matd_t> {
  MatD get toMatD {
    final nrows = ref.nrows;
    final ncols = ref.ncols;
    final data = ref.data.asTypedList(nrows * ncols);
    return MatD(nrows, ncols, data: data);
  }

  void dispose() {
    C.matd_destroy(this);
  }
}
