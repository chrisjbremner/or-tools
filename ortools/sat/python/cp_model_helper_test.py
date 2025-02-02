#!/usr/bin/env python3
# Copyright 2010-2022 Google LLC
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Tests for ortools.sat.python.cp_model_helper."""

from absl.testing import absltest
from ortools.sat.python import cp_model_helper


class CpModelHelperTest(absltest.TestCase):
    def testassert_is_int64(self):
        print("testassert_is_int64")
        self.assertRaises(TypeError, cp_model_helper.assert_is_int64, "Hello")
        self.assertRaises(TypeError, cp_model_helper.assert_is_int64, 1.2)
        self.assertRaises(OverflowError, cp_model_helper.assert_is_int64, 2**63)
        self.assertRaises(
            OverflowError, cp_model_helper.assert_is_int64, -(2**63) - 1
        )
        cp_model_helper.assert_is_int64(123)
        cp_model_helper.assert_is_int64(2**63 - 1)
        cp_model_helper.assert_is_int64(-(2**63))

    def testto_capped_int64(self):
        print("testto_capped_int64")
        self.assertEqual(
            cp_model_helper.to_capped_int64(cp_model_helper.INT_MAX),
            cp_model_helper.INT_MAX,
        )
        self.assertEqual(
            cp_model_helper.to_capped_int64(cp_model_helper.INT_MAX + 1),
            cp_model_helper.INT_MAX,
        )
        self.assertEqual(
            cp_model_helper.to_capped_int64(cp_model_helper.INT_MIN),
            cp_model_helper.INT_MIN,
        )
        self.assertEqual(
            cp_model_helper.to_capped_int64(cp_model_helper.INT_MIN - 1),
            cp_model_helper.INT_MIN,
        )
        self.assertEqual(cp_model_helper.to_capped_int64(15), 15)

    def testcapped_subtraction(self):
        print("testcapped_subtraction")
        self.assertEqual(cp_model_helper.capped_subtraction(10, 5), 5)
        self.assertEqual(
            cp_model_helper.capped_subtraction(cp_model_helper.INT_MIN, 5),
            cp_model_helper.INT_MIN,
        )
        self.assertEqual(
            cp_model_helper.capped_subtraction(cp_model_helper.INT_MIN, -5),
            cp_model_helper.INT_MIN,
        )
        self.assertEqual(
            cp_model_helper.capped_subtraction(cp_model_helper.INT_MAX, 5),
            cp_model_helper.INT_MAX,
        )
        self.assertEqual(
            cp_model_helper.capped_subtraction(cp_model_helper.INT_MAX, -5),
            cp_model_helper.INT_MAX,
        )
        self.assertEqual(
            cp_model_helper.capped_subtraction(2, cp_model_helper.INT_MIN),
            cp_model_helper.INT_MAX,
        )
        self.assertEqual(
            cp_model_helper.capped_subtraction(2, cp_model_helper.INT_MAX),
            cp_model_helper.INT_MIN,
        )
        self.assertRaises(
            OverflowError,
            cp_model_helper.capped_subtraction,
            cp_model_helper.INT_MAX,
            cp_model_helper.INT_MAX,
        )
        self.assertRaises(
            OverflowError,
            cp_model_helper.capped_subtraction,
            cp_model_helper.INT_MIN,
            cp_model_helper.INT_MIN,
        )
        self.assertRaises(TypeError, cp_model_helper.capped_subtraction, 5, "dummy")
        self.assertRaises(TypeError, cp_model_helper.capped_subtraction, "dummy", 5)


if __name__ == "__main__":
    absltest.main()
