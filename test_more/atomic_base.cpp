// $Id$
/* --------------------------------------------------------------------------
CppAD: C++ Algorithmic Differentiation: Copyright (C) 2003-15 Bradley M. Bell

CppAD is distributed under multiple licenses. This distribution is under
the terms of the
                    Eclipse Public License Version 1.0.

A copy of this license is included in the COPYING file of this distribution.
Please visit http://www.coin-or.org/CppAD/ for information on other licenses.
-------------------------------------------------------------------------- */

# include <cppad/cppad.hpp>
namespace {
	using CppAD::vector;
	using CppAD::vectorBool;

	// test pack_sparsity_enum
	class atomic_pack : public CppAD::atomic_base<double>
	{
	public:
		atomic_pack(const std::string& name) :
		CppAD::atomic_base<double>(name, pack_sparsity_enum )
		{ }
	private:
		// forward
		virtual bool forward(
			size_t                    p ,
			size_t                    q ,
			const vector<bool>&      vx ,
			vector<bool>&            vy ,
			const vector<double>&    tx ,
			vector<double>&          ty
		)
		{	size_t n = tx.size() / (q + 1);
			size_t m = ty.size() / (q + 1);
			assert( n == 3 );
			assert( m == 2 );

			// only order zero
			bool ok = q == 0;
			if( ! ok )
				return ok;

			// check for defining variable information
			if( vx.size() > 0 )
			{	ok   &= vx.size() == n;
				vy[0] = vx[2];
				vy[1] = vx[0] || vx[1];
			}

			// Order zero forward mode.
			// y[0] = x[2], y[1] = x[0] * x[1]
			if( p <= 0 )
			{	ty[0] = tx[2];
				ty[1] = tx[0] * tx[1];
			}
			return ok;
		}
		// for_sparse_jac
		virtual bool for_sparse_jac(
			size_t                          p ,
			const vectorBool&               r ,
			vectorBool&                     s )
		{	// This function needed if using f.ForSparseJac
			size_t n = r.size() / p;
			size_t m = s.size() / p;
			assert( n == 3 );
			assert( m == 2 );

			// sparsity for S(x) = f'(x) * R  = [ 0,   0, 1 ] * R
			//                                  [ x1, x0, 0 ]
			for(size_t j = 0; j < p; j++)
			{	s[ 0 * p + j] = r[ 2 * p + j];
				s[ 1 * p + j] = r[ 0 * p + j] || r[ 1 * p + j];
			}
			return true;
		}
		virtual bool rev_sparse_jac(
			size_t                                p  ,
			const vectorBool&                     rt ,
			vectorBool&                           st )
		{	// This function needed if using RevSparseJac or optimize
			size_t n = st.size() / p;
			size_t m = rt.size() / p;
			assert( n == 3 );
			assert( m == 2 );

			//                                       [ 0, x1 ]
			// sparsity for S(x)^T = f'(x)^T * R^T = [ 0, x0 ] * R^T
			//                                       [ 1, 0  ]
			for(size_t j = 0; j < p; j++)
			{	st[ 0 * p + j ] = rt[ 1 * m + j ];
				st[ 1 * p + j ] = rt[ 1 * m + j ];
				st[ 2 * p + j ] = rt[ 0 * m + j ];
			}
			return true;
		}
		virtual bool rev_sparse_hes(
			const vector<bool>&                   vx,
			const vector<bool>&                   s ,
			      vector<bool>&                   t ,
			size_t                                p ,
			const vectorBool&                     r ,
			const vectorBool&                     u ,
			vectorBool&                           v )
		{	// This function needed if using RevSparseHes
			size_t m = s.size();
			size_t n = t.size();
			assert( r.size() == n * p );
			assert( u.size() == m * p );
			assert( v.size() == n * p );
			assert( n == 3 );
			assert( m == 2 );

			// sparsity for T(x) = S(x) * f'(x) = S(x) * [  0,  0,  1 ]
			//                                           [ x1, x0,  0 ]
			t[0] = s[1];
			t[1] = s[1];
			t[2] = s[0];

			// V(x) = f'(x)^T * g''(y) * f'(x) * R  +  g'(y) * f''(x) * R
			// U(x) = g''(y) * f'(x) * R
			// S(x) = g'(y)

			//                               [ 0, x1 ]
			// sparsity for f'(x)^T * U(x) = [ 0, x0 ] * U(x)
			//                               [ 1, 0  ]
			size_t j;
			for(j = 0; j < p; j++)
			{	v[ 0 * p + j ] = u[ 1 * m + j ];
				v[ 1 * p + j ] = u[ 1 * m + j ];
				v[ 2 * p + j ] = u[ 0 * m + j ];
			}

			// include forward Jacobian sparsity in Hessian sparsity
			//                                                [ 0, 1, 0 ]
			// sum_i S_i (x) g'(y) * f_i''(x) * R = S_1 (x) * [ 1, 0, 0 ] * R
			//                                                [ 0, 0, 0 ]
			if( s[1] )
			{	for(j = 0; j < p; j++)
				{	v[ 0 * p + j ] = bool(v[0 * p + j]) | bool(r[1 * p + j]);
					v[ 1 * p + j ] = bool(v[1 * p + j]) | bool(r[0 * p + j]);
				}
			}
			return true;
		}
	};
}
bool atomic_base(void)
{	bool ok = true;
	using CppAD::AD;
	using CppAD::NearEqual;
	double eps = 10. * std::numeric_limits<double>::epsilon();

	// Create the atomic get_started object
	atomic_pack afun("atomic_pack");

	size_t n = 3;
	size_t m = 2;
	vector< AD<double> > ax(n), ay(m);
	for(size_t j = 0; j < n; j++)
		ax[j] = double(j + 1);

	// declare independent variables and start tape recording
	CppAD::Independent(ax);

	// call user function
	afun(ax, ay);

	// create f: x -> y and stop tape recording
	CppAD::ADFun<double> f;
	f.Dependent (ax, ay);  // f(x) = x

	// check function value
	ok &= NearEqual(ay[0] , ax[2],  eps, eps);
	ok &= NearEqual(ay[1] , ax[0] * ax[1],  eps, eps);

	// for_sparse_jac and rev_sparse_jac
	for(size_t dir = 0; dir < 2; dir++)
	{	size_t ell;
		if( dir == 0 )
			ell = n;
		else
			ell = m;

		// identity martrix
		vectorBool r(ell * ell);
		for(size_t i = 0; i < ell; i++)
			for(size_t j = 0; j < ell; j++)
				r[i * ell + j] = (i == j);

		vectorBool s;
		if( dir == 0 )
			s = f.ForSparseJac(n, r);
		else
			s = f.RevSparseJac(m, r);

		// check Jacobian result
		ok  &= s.size() == m * n;
		ok  &= s[0 * n + 0] == false;
		ok  &= s[0 * n + 1] == false;
		ok  &= s[0 * n + 2] == true;
		ok  &= s[1 * n + 0] == true;
		ok  &= s[1 * n + 1] == true;
		ok  &= s[1 * n + 2] == false;
	}

	// rev_sparse_hes
	vectorBool s(m), h(n * n);
	s[0] = true;
	s[1] = true;
	h    = f.RevSparseHes(n, s);
	for(size_t i = 0; i < n; i++)
	{	for(size_t j = 0; j < n; j++)
		{	bool check = false;
			check     |= (i == 0) && (j == 1);
			check     |= (j == 0) && (i == 1);
			ok        &= h[ i * n + j] == check;
		}
	}
	//
	return ok;
}
